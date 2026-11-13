import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/chat/bloc/chat_channel_cubit.dart';
import 'package:round_ai/features/chat/bloc/chat_channels_cubit.dart';
import 'package:round_ai/features/chat/chat_unread_badge.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_stream_event.dart';
import 'package:round_ai/features/chat/models/chat_timeline_item.dart';
import 'package:round_ai/features/chat/repository/chat_repository_impl.dart';
import 'package:round_ai/features/chat/services/chat_realtime_controller.dart';
import 'package:round_ai/features/chat/services/chat_stream_client.dart';
import 'package:round_ai/features/chat/services/sse_parser.dart';

import 'support/fake_adapter.dart';

ChatStreamEvent _event({
  required String id,
  required int seq,
  String channelId = 'ch1',
  String body = 'hi',
  ChatStreamEventType type = ChatStreamEventType.message,
  String senderId = 'u2',
}) {
  return ChatStreamEvent(
    type: type,
    eventId: '$seq',
    message: ChatMessage(
      id: id,
      channelId: channelId,
      senderId: senderId,
      body: body,
      seq: seq,
      deleted: type == ChatStreamEventType.messageDeleted,
      createdAt: DateTime.utc(2026, 11, 13),
    ),
  );
}

class FakeChatStreamClient implements ChatStreamClient {
  final List<StreamController<ChatStreamEvent>> controllers =
      <StreamController<ChatStreamEvent>>[];
  final List<String?> lastEventIds = <String?>[];
  int connectCount = 0;
  bool failNext = false;
  ApiError? failWith;

  StreamController<ChatStreamEvent> get latest => controllers.last;

  void push(ChatStreamEvent event) {
    if (controllers.isEmpty || latest.isClosed) return;
    latest.add(event);
  }

  void drop({Object? error}) {
    if (controllers.isEmpty) return;
    final StreamController<ChatStreamEvent> c = latest;
    if (error != null) {
      c.addError(error);
    }
    unawaited(c.close());
  }

  @override
  Stream<ChatStreamEvent> connect({
    String? lastEventId,
    CancelToken? cancelToken,
    void Function()? onActivity,
  }) {
    connectCount++;
    lastEventIds.add(lastEventId);
    final StreamController<ChatStreamEvent> controller =
        StreamController<ChatStreamEvent>();
    controllers.add(controller);
    if (failNext) {
      failNext = false;
      scheduleMicrotask(() {
        controller.addError(
          failWith ??
              const ApiError(code: 'network_error', message: '', status: null),
        );
        unawaited(controller.close());
      });
    }
    cancelToken?.whenCancel.then((_) {
      if (!controller.isClosed) unawaited(controller.close());
    });
    return controller.stream;
  }

  @override
  void disconnect() {
    for (final StreamController<ChatStreamEvent> c in controllers) {
      if (!c.isClosed) unawaited(c.close());
    }
  }

  @override
  void clear() => disconnect();
}

Future<ApiClient> _client(FakeAdapter adapter) async {
  final SessionStore session = SessionStore(MemoryTokenStore());
  await session.save('tok', persist: false);
  return ApiClient(session: session, dio: fakeDio(adapter));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SseParser', () {
    test('parses events, ignores comments, dedupes frames', () {
      final SseParser parser = SseParser();
      int heartbeats = 0;
      final List<ChatStreamEvent> events = parser
          .add(
            ': ping\n\n'
            'id: 3\n'
            'event: message\n'
            'data: {"id":"m1","channel_id":"ch1","sender_id":"u1","body":"a","seq":3,"deleted":false}\n'
            '\n'
            'id: 3\n'
            'event: message_edited\n'
            'data: {"id":"m1","channel_id":"ch1","sender_id":"u1","body":"b","seq":3,"deleted":false,"edited_at":"2026-11-13T11:00:00.000Z"}\n'
            '\n',
            onHeartbeat: () => heartbeats++,
          )
          .toList();
      expect(heartbeats, 1);
      expect(events.length, 2);
      expect(events.first.type, ChatStreamEventType.message);
      expect(events.first.message.body, 'a');
      expect(events.last.type, ChatStreamEventType.messageEdited);
      expect(events.last.eventId, '3');
    });
  });

  group('ChatRealtimeController', () {
    test('dedupes replay and tracks Last-Event-ID', () {
      fakeAsync((FakeAsync async) {
        final FakeChatStreamClient client = FakeChatStreamClient();
        final ChatRealtimeController rt = ChatRealtimeController(
          client: client,
          random: RandomStub(),
        );
        final List<ChatStreamEvent> seen = <ChatStreamEvent>[];
        rt.events.listen(seen.add);

        rt.setSignedIn(true);
        rt.onForeground();
        rt.start();
        async.flushMicrotasks();
        expect(client.connectCount, 1);

        final ChatStreamEvent a = _event(id: 'm1', seq: 1);
        rt; // ignore
        client.push(a);
        client.push(a); // duplicate
        client.push(_event(id: 'm2', seq: 2));
        async.flushMicrotasks();

        expect(seen.length, 2);
        expect(rt.lastEventId, '2');

        rt.clear();
      });
    });

    test('reconnects after drop with Last-Event-ID', () {
      fakeAsync((FakeAsync async) {
        final FakeChatStreamClient client = FakeChatStreamClient();
        final ChatRealtimeController rt = ChatRealtimeController(
          client: client,
          random: RandomStub(),
          maxBackoff: const Duration(milliseconds: 100),
        );
        rt.setSignedIn(true);
        rt.onForeground();
        rt.start();
        async.flushMicrotasks();

        client.push(_event(id: 'm1', seq: 5));
        async.flushMicrotasks();
        expect(rt.lastEventId, '5');

        client.drop();
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        expect(client.connectCount, greaterThanOrEqualTo(2));
        expect(client.lastEventIds.last, '5');
        rt.clear();
      });
    });

    test('emits gap when seq jumps', () {
      fakeAsync((FakeAsync async) {
        final FakeChatStreamClient client = FakeChatStreamClient();
        final ChatRealtimeController rt = ChatRealtimeController(
          client: client,
          random: RandomStub(),
        );
        ChatRealtimeGap? gap;
        rt.gaps.listen((ChatRealtimeGap g) => gap = g);

        rt.setSignedIn(true);
        rt.onForeground();
        rt.start();
        async.flushMicrotasks();

        client.push(_event(id: 'm1', seq: 1));
        client.push(_event(id: 'm2', seq: 5));
        async.flushMicrotasks();

        expect(gap, isNotNull);
        expect(gap!.fromSeq, 1);
        expect(gap!.toSeq, 5);
        rt.clear();
      });
    });

    test('background disconnects; resume reconnects', () {
      fakeAsync((FakeAsync async) {
        final FakeChatStreamClient client = FakeChatStreamClient();
        final ChatRealtimeController rt = ChatRealtimeController(
          client: client,
          random: RandomStub(),
        );
        rt.setSignedIn(true);
        rt.onForeground();
        rt.start();
        async.flushMicrotasks();
        expect(client.connectCount, 1);

        rt.onBackground();
        async.flushMicrotasks();
        expect(rt.status.value, ChatRealtimeStatus.paused);

        rt.onForeground();
        async.flushMicrotasks();
        expect(client.connectCount, greaterThanOrEqualTo(2));
        rt.clear();
      });
    });

    test('permanent stop on chat_disabled', () {
      fakeAsync((FakeAsync async) {
        final FakeChatStreamClient client = FakeChatStreamClient()
          ..failNext = true
          ..failWith = const ApiError(
            code: 'chat_disabled',
            message: '',
            status: 503,
          );
        final ChatRealtimeController rt = ChatRealtimeController(
          client: client,
          random: RandomStub(),
        );
        rt.setSignedIn(true);
        rt.onForeground();
        rt.start();
        async.flushMicrotasks();
        expect(rt.status.value, ChatRealtimeStatus.stopped);

        async.elapse(const Duration(seconds: 5));
        expect(client.connectCount, 1);
        rt.clear();
      });
    });
  });

  group('live cubit apply', () {
    test('channel cubit sorts out-of-order events by seq', () async {
      final FakeAdapter adapter = FakeAdapter(
        (RequestOptions o) {
          if (o.path.endsWith('/read')) {
            return FakeReply(200, <String, Object>{
              'channel_id': 'ch1',
              'last_read_seq': 2,
              'unread': 0,
            });
          }
          return FakeReply(200, <String, Object>{'messages': <Object>[]});
        },
      );
      final ChatChannelCubit cubit = ChatChannelCubit(
        chat: ChatRepositoryImpl(await _client(adapter)),
        channelId: 'ch1',
        currentUserId: 'u1',
      );
      await cubit.load();
      cubit.applyStreamEvent(_event(id: 'm2', seq: 2, body: 'second'));
      cubit.applyStreamEvent(_event(id: 'm1', seq: 1, body: 'first'));
      expect(
        cubit.state.items.map((ChatTimelineItem i) => i.message.seq).toList(),
        <int>[1, 2],
      );
      await cubit.close();
    });

    test('channels cubit bumps unread unless viewing', () async {
      final FakeAdapter adapter = FakeAdapter(
        (RequestOptions o) => FakeReply(200, <Object>[
          <String, Object?>{
            'id': 'ch1',
            'team_id': 't1',
            'name': 'general',
            'type': 'team',
            'patient_id': null,
            'archived': false,
            'unread': 0,
            'created_at': '2026-11-13T10:00:00.000Z',
          },
        ]),
      );
      final ChatUnreadBadge badge = ChatUnreadBadge();
      final FakeChatStreamClient client = FakeChatStreamClient();
      final ChatRealtimeController rt = ChatRealtimeController(
        client: client,
        random: RandomStub(),
      );
      final ChatChannelsCubit cubit = ChatChannelsCubit(
        ChatRepositoryImpl(await _client(adapter)),
        badge,
        realtime: rt,
        currentUserId: 'u1',
      );
      await cubit.load();
      cubit.applyStreamEvent(
        _event(id: 'm1', seq: 1),
        activeChannelId: null,
        currentUserId: 'u1',
      );
      expect(cubit.state.totalUnread, 1);
      expect(badge.value, 1);

      cubit.applyStreamEvent(
        _event(id: 'm2', seq: 2),
        activeChannelId: 'ch1',
        currentUserId: 'u1',
      );
      expect(cubit.state.totalUnread, 0);
      await cubit.close();
      rt.clear();
    });

    test('gap triggers after_seq refetch on open channel', () async {
      int messageGets = 0;
      final FakeAdapter adapter = FakeAdapter((RequestOptions o) {
        if (o.path.endsWith('/messages')) {
          messageGets++;
          if (messageGets == 1) {
            return FakeReply(200, <String, Object>{
              'messages': <Object>[
                <String, Object?>{
                  'id': 'm1',
                  'channel_id': 'ch1',
                  'sender_id': 'u2',
                  'body': 'one',
                  'seq': 1,
                  'parent_id': null,
                  'deleted': false,
                  'created_at': '2026-11-13T10:00:00.000Z',
                },
              ],
            });
          }
          expect(o.queryParameters['after_seq'], 1);
          return FakeReply(200, <String, Object>{
            'messages': <Object>[
              <String, Object?>{
                'id': 'm3',
                'channel_id': 'ch1',
                'sender_id': 'u2',
                'body': 'three',
                'seq': 3,
                'parent_id': null,
                'deleted': false,
                'created_at': '2026-11-13T10:00:00.000Z',
              },
            ],
          });
        }
        if (o.path.endsWith('/read')) {
          return FakeReply(200, <String, Object>{
            'channel_id': 'ch1',
            'last_read_seq': 3,
            'unread': 0,
          });
        }
        return const FakeReply(404, <String, Object>{});
      });
      final ChatChannelCubit cubit = ChatChannelCubit(
        chat: ChatRepositoryImpl(await _client(adapter)),
        channelId: 'ch1',
        currentUserId: 'u1',
      );
      await cubit.load();
      await cubit.refetchAfterGap();
      expect(
        cubit.state.items.map((ChatTimelineItem i) => i.message.id).toList(),
        <String>['m1', 'm3'],
      );
      await cubit.close();
    });
  });
}

/// Deterministic jitter for reconnect tests.
class RandomStub implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}
