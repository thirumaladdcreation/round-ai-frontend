import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/config/shell_tabs.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/chat/bloc/chat_channel_cubit.dart';
import 'package:round_ai/features/chat/bloc/chat_channels_cubit.dart';
import 'package:round_ai/features/chat/chat_unread_badge.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_timeline_item.dart';
import 'package:round_ai/features/chat/repository/chat_repository_impl.dart';
import 'package:round_ai/features/chat/repository/demo_chat_repository.dart';
import 'package:round_ai/features/chat/screens/chat_channels_screen.dart';
import 'package:round_ai/shared/widgets/app_bottom_nav_bar.dart';
import 'package:round_ai/shared/widgets/chat_disabled_banner.dart';

import 'support/fake_adapter.dart';

Future<ApiClient> _client(FakeAdapter adapter) async {
  final SessionStore session = SessionStore(MemoryTokenStore());
  await session.save('tok', persist: false);
  return ApiClient(session: session, dio: fakeDio(adapter));
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      extensions: const <ThemeExtension<dynamic>>[AppColors.light],
    ),
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AppFeatures.forceAll = null);

  group('H1 shell', () {
    test('chat tab is on', () {
      AppFeatures.forceAll = null;
      expect(AppFeatures.chat, isTrue);
      expect(ShellTabs.visible.contains(ShellTab.chat), isTrue);
    });

    testWidgets('bottom bar shows Patients and Chat', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: AppBottomNavBar(
              currentIndex: 0,
              onItemSelected: (_) {},
              chatBadge: '2',
            ),
          ),
        ),
      );
      expect(find.text('Patients'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(find.text('Scribe'), findsNothing);
    });
  });

  group('ChatChannelsCubit', () {
    test('groups channels and updates badge', () async {
      final FakeAdapter adapter = FakeAdapter(
        (RequestOptions o) => FakeReply(200, <Object>[
          <String, Object?>{
            'id': 'c1',
            'team_id': 't1',
            'name': 'general',
            'type': 'team',
            'patient_id': null,
            'archived': false,
            'unread': 2,
            'created_at': '2026-11-13T10:00:00.000Z',
          },
          <String, Object?>{
            'id': 'c2',
            'team_id': 't1',
            'name': 'Room 1',
            'type': 'patient',
            'patient_id': 'p1',
            'archived': false,
            'unread': 0,
            'created_at': '2026-11-13T10:00:00.000Z',
          },
        ]),
      );
      final ChatUnreadBadge badge = ChatUnreadBadge();
      final ChatChannelsCubit cubit = ChatChannelsCubit(
        ChatRepositoryImpl(await _client(adapter)),
        badge,
      );
      await cubit.load();
      expect(cubit.state.sections.length, 2);
      expect(cubit.state.sections.first.title, 'Team');
      expect(cubit.state.totalUnread, 2);
      expect(badge.value, 2);
      await cubit.close();
    });

    test('chat_disabled clears badge', () async {
      final FakeAdapter adapter = FakeAdapter(
        (RequestOptions o) => FakeReply(503, <String, Object>{
          'error': <String, String>{
            'code': 'chat_disabled',
            'message': 'off',
          },
        }),
      );
      final ChatUnreadBadge badge = ChatUnreadBadge()..setTotal(4);
      final ChatChannelsCubit cubit = ChatChannelsCubit(
        ChatRepositoryImpl(await _client(adapter)),
        badge,
      );
      await cubit.load();
      expect(cubit.state.chatDisabled, isTrue);
      expect(badge.value, 0);
      await cubit.close();
    });
  });

  group('ChatChannelCubit', () {
    test('optimistic send becomes synced', () async {
      int posts = 0;
      final FakeAdapter adapter = FakeAdapter((RequestOptions o) {
        if (o.method == 'GET' && o.path.contains('/messages')) {
          return FakeReply(200, <String, Object>{
            'messages': <Object>[],
          });
        }
        if (o.method == 'POST' && o.path.endsWith('/messages')) {
          posts++;
          return FakeReply(200, <String, Object?>{
            'id': 'm-server',
            'channel_id': 'ch1',
            'sender_id': 'u1',
            'body': 'hello team',
            'seq': 3,
            'parent_id': null,
            'edited_at': null,
            'deleted_at': null,
            'deleted': false,
            'created_at': '2026-11-13T10:00:00.000Z',
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
      await cubit.send('hello team');
      expect(posts, 1);
      expect(cubit.state.items.single.message.id, 'm-server');
      expect(cubit.state.items.single.status, ChatSendStatus.synced);
      await cubit.close();
    });

    test('failed send can retry', () async {
      int posts = 0;
      final FakeAdapter adapter = FakeAdapter((RequestOptions o) {
        if (o.method == 'GET') {
          return FakeReply(200, <String, Object>{'messages': <Object>[]});
        }
        if (o.method == 'POST' && o.path.endsWith('/messages')) {
          posts++;
          if (posts == 1) {
            return FakeReply(429, <String, Object>{
              'error': <String, String>{
                'code': 'rate_limited',
                'message': 'slow',
              },
            });
          }
          return FakeReply(200, <String, Object?>{
            'id': 'm2',
            'channel_id': 'ch1',
            'sender_id': 'u1',
            'body': 'retry me',
            'seq': 1,
            'parent_id': null,
            'edited_at': null,
            'deleted_at': null,
            'deleted': false,
            'created_at': '2026-11-13T10:00:00.000Z',
          });
        }
        if (o.path.endsWith('/read')) {
          return FakeReply(200, <String, Object>{
            'channel_id': 'ch1',
            'last_read_seq': 1,
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
      await cubit.send('retry me');
      expect(cubit.state.items.single.status, ChatSendStatus.failed);
      expect(cubit.state.actionError?.kind, ApiErrorKind.rateLimited);
      final String localId = cubit.state.items.single.message.id;
      await cubit.retry(localId);
      expect(posts, 2);
      expect(cubit.state.items.single.message.id, 'm2');
      expect(cubit.state.items.single.status, ChatSendStatus.synced);
      await cubit.close();
    });
  });

  group('demo chat UI', () {
    testWidgets('inbox lists demo channels', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ChatChannelsScreen(
            chatRepository: DemoChatRepository(),
            unreadBadge: ChatUnreadBadge(),
            chatOff: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chat'), findsWidgets);
      expect(find.text('general'), findsOneWidget);
      expect(find.text('COMMAND CENTER'), findsOneWidget);
      expect(find.text('TEAM'), findsOneWidget);
    });

    testWidgets('chatOff shows calm banner and hides list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ChatChannelsScreen(
            chatRepository: DemoChatRepository(),
            unreadBadge: ChatUnreadBadge(),
            chatOff: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(ChatDisabledBanner.message), findsOneWidget);
      expect(find.text('general'), findsNothing);
    });
  });

  group('DemoChatRepository', () {
    test('send edit delete round-trip', () async {
      final DemoChatRepository demo = DemoChatRepository();
      final Result<ChatMessage> sent = await demo.sendMessage(
        'demo-general',
        body: 'Note for the team',
      );
      expect(sent, isA<Ok<ChatMessage>>());
      final String id = (sent as Ok<ChatMessage>).value.id;
      final Result<ChatMessage> edited = await demo.editMessage(
        id,
        body: 'Updated note',
      );
      expect((edited as Ok<ChatMessage>).value.body, 'Updated note');
      expect(edited.value.isEdited, isTrue);
      final Result<ChatMessage> deleted = await demo.deleteMessage(id);
      expect((deleted as Ok<ChatMessage>).value.deleted, isTrue);
      expect(deleted.value.body, isEmpty);
    });
  });
}
