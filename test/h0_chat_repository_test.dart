import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/authentication/models/app_user.dart';
import 'package:round_ai/features/chat/cache/chat_memory_cache.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_stream_event.dart';
import 'package:round_ai/features/chat/models/chat_summary_draft.dart';
import 'package:round_ai/features/chat/repository/chat_repository_impl.dart';
import 'package:round_ai/features/chat/repository/demo_chat_repository.dart';

import 'support/fake_adapter.dart';

Future<ApiClient> _client(FakeAdapter adapter) async {
  final SessionStore session = SessionStore(MemoryTokenStore());
  await session.save('tok', persist: false);
  return ApiClient(session: session, dio: fakeDio(adapter));
}

Map<String, Object?> _channel({
  String id = 'ch1',
  String type = 'team',
  int unread = 0,
}) => <String, Object?>{
  'id': id,
  'team_id': 't1',
  'name': 'general',
  'type': type,
  'patient_id': type == 'patient' ? 'p1' : null,
  'archived': false,
  'unread': unread,
  'created_at': '2026-11-13T10:00:00.000Z',
};

Map<String, Object?> _message({
  String id = 'm1',
  int seq = 1,
  String body = 'hello',
  bool deleted = false,
}) => <String, Object?>{
  'id': id,
  'channel_id': 'ch1',
  'sender_id': 'u1',
  'body': deleted ? '' : body,
  'seq': seq,
  'parent_id': null,
  'edited_at': null,
  'deleted_at': deleted ? '2026-11-13T11:00:00.000Z' : null,
  'deleted': deleted,
  'created_at': '2026-11-13T10:00:00.000Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('H0 feature flag', () {
    test('chat flag is on after H1', () {
      AppFeatures.forceAll = null;
      expect(AppFeatures.chat, isTrue);
    });
  });

  group('models', () {
    test('channel and message parse snake_case; deleted clears body', () {
      final ChatChannel channel = ChatChannel.fromJson(
        Map<String, dynamic>.from(_channel(type: 'patient', unread: 3)),
      );
      expect(channel.type, ChatChannelType.patient);
      expect(channel.patientId, 'p1');
      expect(channel.unread, 3);

      final ChatMessage gone = ChatMessage.fromJson(
        Map<String, dynamic>.from(
          _message(body: 'PHI should vanish', deleted: true),
        ),
      );
      expect(gone.deleted, isTrue);
      expect(gone.body, isEmpty);
    });

    test('MeProfile reads chat_enabled from /me', () {
      final MeProfile profile = MeProfile.fromJson(<String, dynamic>{
        'id': 'u1',
        'name': 'A',
        'email': 'a@x',
        'role': 'Resident',
        'teams': <Object>[],
        'ai_enabled': true,
        'chat_enabled': true,
      });
      expect(profile.chatEnabled, isTrue);
      expect(profile.aiEnabled, isTrue);
    });

    test('stream event parses message_edited', () {
      final ChatStreamEvent event = ChatStreamEvent.fromSse(
        eventName: 'message_edited',
        data: _message(body: 'edited'),
        eventId: '7',
      );
      expect(event.type, ChatStreamEventType.messageEdited);
      expect(event.eventId, '7');
      expect(event.message.body, 'edited');
    });

    test('summary draft never implies auto-post', () {
      final ChatSummaryDraft draft = ChatSummaryDraft.fromEnvelope(
        AiEnvelope.fromJson(<String, dynamic>{
          'artifact_id': 'a1',
          'operation': 'summarize_chat_thread',
          'patient_id': '',
          'context_revision': 0,
          'status': 'draft',
          'review_state': 'draft',
          'outdated': false,
          'requires_review': true,
          'provider': 'demo',
          'model': 'demo',
          'prompt_version': '1',
          'generation_ms': 1,
          'created_at': '2026-11-13T10:00:00.000Z',
          'content': <String, dynamic>{
            'bullets': <Object>[
              <String, Object>{
                'text': 'Stay hydrated',
                'message_ids': <String>['m1'],
              },
            ],
            'open_questions': <String>[],
            'missing_information': <String>[],
            'channel_id': 'ch1',
            'disclaimer': 'AI draft · review required',
          },
        }),
      );
      expect(draft.requiresReview, isTrue);
      expect(draft.disclaimer.toLowerCase(), contains('review'));
      expect(draft.bullets.single.text, 'Stay hydrated');
    });
  });

  group('ChatMemoryCache', () {
    test('bounds and clears without retaining channel ids after clear', () {
      final ChatMemoryCache cache = ChatMemoryCache(maxMessagesPerChannel: 2);
      cache.putAll('ch1', <ChatMessage>[
        ChatMessage.fromJson(Map<String, dynamic>.from(_message(id: 'a', seq: 1))),
        ChatMessage.fromJson(Map<String, dynamic>.from(_message(id: 'b', seq: 2))),
        ChatMessage.fromJson(Map<String, dynamic>.from(_message(id: 'c', seq: 3))),
      ]);
      expect(cache.messagesFor('ch1').map((ChatMessage m) => m.id), <String>['b', 'c']);
      cache.clear();
      expect(cache.messagesFor('ch1'), isEmpty);
    });
  });

  group('ChatRepositoryImpl', () {
    test('lists channels and caches messages; send enforces max length', () async {
      final FakeAdapter adapter = FakeAdapter((RequestOptions o) {
        if (o.path == '/channels') {
          return FakeReply(200, <Object>[_channel(unread: 1)]);
        }
        if (o.path == '/channels/ch1/messages') {
          return FakeReply(200, <String, Object>{
            'messages': <Object>[_message()],
          });
        }
        return const FakeReply(404, <String, Object>{'error': 'missing'});
      });

      final ChatMemoryCache cache = ChatMemoryCache();
      final ChatRepositoryImpl repo = ChatRepositoryImpl(
        await _client(adapter),
        cache: cache,
      );

      final Result<List<ChatChannel>> channels = await repo.listChannels();
      expect(channels, isA<Ok<List<ChatChannel>>>());
      expect((channels as Ok<List<ChatChannel>>).value.single.name, 'general');

      final Result<List<ChatMessage>> messages = await repo.listMessages('ch1');
      expect(messages, isA<Ok<List<ChatMessage>>>());
      expect(cache.messagesFor('ch1'), isNotEmpty);

      final Result<ChatMessage> tooLong = await repo.sendMessage(
        'ch1',
        body: 'x' * (kChatMaxBodyLength + 1),
      );
      expect(tooLong, isA<Err<ChatMessage>>());
      expect(
        ((tooLong as Err<ChatMessage>).failure as ApiFailure).error.kind,
        ApiErrorKind.messageTooLong,
      );

      repo.clearLocalState();
      expect(cache.messagesFor('ch1'), isEmpty);
    });

    test('maps chat_disabled from the wire', () async {
      final FakeAdapter adapter = FakeAdapter(
        (RequestOptions o) => FakeReply(503, <String, Object>{
          'error': <String, String>{
            'code': 'chat_disabled',
            'message': 'off',
          },
        }),
      );
      final ChatRepositoryImpl repo = ChatRepositoryImpl(await _client(adapter));
      final Result<List<ChatChannel>> result = await repo.listChannels();
      expect(result, isA<Err<List<ChatChannel>>>());
      final ApiFailure failure =
          (result as Err<List<ChatChannel>>).failure as ApiFailure;
      expect(failure.error.kind, ApiErrorKind.chatDisabled);
      expect(
        failure.error.userMessage,
        'Chat is turned off by your administrator.',
      );
    });

    test('rate_limited and duplicate_message map distinctly', () {
      expect(
        ApiError.fromResponse(429, <String, Object>{
          'error': <String, String>{'code': 'rate_limited', 'message': 'x'},
        }).kind,
        ApiErrorKind.rateLimited,
      );
      expect(
        ApiError.fromResponse(429, <String, Object>{
          'error': <String, String>{'code': 'duplicate_message', 'message': 'x'},
        }).kind,
        ApiErrorKind.duplicateMessage,
      );
      expect(
        ApiError.fromResponse(429, <String, Object>{
          'error': <String, String>{'code': 'daily_limit', 'message': 'x'},
        }).kind,
        ApiErrorKind.dailyLimit,
      );
    });
  });

  group('DemoChatRepository', () {
    test('seeded send works on general', () async {
      final DemoChatRepository demo = DemoChatRepository();
      final Result<ChatMessage> send = await demo.sendMessage(
        'demo-general',
        body: 'hi',
      );
      expect(send, isA<Ok<ChatMessage>>());
      expect((send as Ok<ChatMessage>).value.body, 'hi');
    });
  });
}
