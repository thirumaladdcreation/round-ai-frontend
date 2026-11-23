import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/config/shell_tabs.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_log_interceptor.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/chat/cache/chat_memory_cache.dart';
import 'package:round_ai/features/chat/cache/chat_people_directory.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_person.dart';
import 'package:round_ai/features/chat/models/chat_push_payload.dart';
import 'package:round_ai/features/chat/repository/demo_chat_repository.dart';
import 'package:round_ai/features/chat/widgets/chat_mention_composer.dart';
import 'package:round_ai/shared/widgets/privacy_shield.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AppFeatures.forceAll = null);

  group('feature surface', () {
    test('chat is live on the bottom bar; scribe is secondary', () {
      AppFeatures.forceAll = null;
      expect(AppFeatures.chat, isTrue);
      expect(ShellTabs.visible.contains(ShellTab.chat), isTrue);
      expect(ShellTabs.visible.contains(ShellTab.scribe), isFalse);
      expect(AppRoutes.chat, '/chat');
      expect(AppRoutes.scribe, '/scribe');
      expect(AppRoutes.chatSummaryPath('c1'), '/chat/c1/summary');
    });
  });

  group('log / notification hygiene', () {
    test('API logger never prints chat body values', () {
      expect(
        ApiLogInterceptor.describe(<String, Object?>{
          'body': 'Creatinine rose overnight for Rosa',
          'channel_id': 'ch1',
        }),
        'object(body, channel_id)',
      );
      expect(
        ApiLogInterceptor.describe('secret message text'),
        'text(19 chars)',
      );
    });

    test('push display strings stay generic', () {
      expect(ChatPushPayload.displayTitle, 'New message');
      expect(ChatPushPayload.displayBody, 'Open RoundsAI');
      final ChatPushPayload payload = ChatPushPayload.parse(<Object?, Object?>{
        'title': 'Rosa Martinez',
        'body': 'Lab update',
        'channel_id': 'demo-patient-1',
      });
      expect(payload.channelId, 'demo-patient-1');
      // Parsed object must not retain remote title/body fields.
      expect(payload.routePath, '/chat/demo-patient-1');
    });
  });

  group('memory cache + sign-out', () {
    test('memory cache drops messages on clear', () {
      final ChatMemoryCache cache = ChatMemoryCache(maxMessagesPerChannel: 3);
      cache.putAll('ch', <ChatMessage>[
        const ChatMessage(
          id: '1',
          channelId: 'ch',
          senderId: 'u',
          body: 'PHI one',
          seq: 1,
          deleted: false,
        ),
        const ChatMessage(
          id: '2',
          channelId: 'ch',
          senderId: 'u',
          body: 'PHI two',
          seq: 2,
          deleted: false,
        ),
      ]);
      expect(cache.messagesFor('ch'), hasLength(2));
      cache.clear();
      expect(cache.messagesFor('ch'), isEmpty);
    });

    test('demo clearLocalState empties then re-seeds', () async {
      final DemoChatRepository chat = DemoChatRepository();
      final Result<List<ChatChannel>> before = await chat.listChannels();
      expect((before as Ok<List<ChatChannel>>).value, isNotEmpty);
      chat.clearLocalState();
      final Result<List<ChatChannel>> after = await chat.listChannels();
      expect((after as Ok<List<ChatChannel>>).value, isNotEmpty);
    });

    test('logout clears chat badge, people, and push association', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await InjectionContainer.instance.init(tokenStore: MemoryTokenStore());
      final InjectionContainer di = InjectionContainer.instance;
      di.chatUnreadBadge.setTotal(4);
      di.chatPeople.upsert(
        const ChatPerson(id: 't1', displayName: 'Jordan Lee'),
      );
      expect(di.chatUnreadBadge.value, 4);
      expect(di.chatPeople['t1']?.displayName, 'Jordan Lee');

      await di.logout();
      expect(di.chatUnreadBadge.value, 0);
      expect(di.chatPeople['t1'], isNull);
      expect(di.chatPeople.all, isEmpty);
      expect(di.isLoggedIn, isFalse);
    });
  });

  group('accessibility', () {
    testWidgets('composer exposes send and patient reminder', (
      WidgetTester tester,
    ) async {
      final TextEditingController c = TextEditingController();
      final FocusNode focus = FocusNode();
      final ChatPeopleDirectory people = ChatPeopleDirectory()
        ..upsert(const ChatPerson(id: 't1', displayName: 'Jordan Lee'));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[AppColors.light],
          ),
          home: Scaffold(
            body: ChatMentionComposer(
              controller: c,
              focusNode: focus,
              enabled: true,
              onSend: () {},
              people: people,
              showPatientReminder: true,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Send message'), findsOneWidget);
      expect(
        find.textContaining('Do not paste names'),
        findsOneWidget,
      );
    });

    testWidgets('privacy cover hides chart text from switcher stack', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[AppColors.light],
          ),
          home: const PrivacyShield(child: Text('patient chart on screen')),
        ),
      );
      expect(find.byKey(const ValueKey<String>('privacy-cover')), findsNothing);
      expect(find.text('patient chart on screen'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('privacy-cover')),
        findsOneWidget,
      );
    });
  });
}
