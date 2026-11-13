import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/chat/bloc/chat_channel_cubit.dart';
import 'package:round_ai/features/chat/bloc/chat_search_cubit.dart';
import 'package:round_ai/features/chat/cache/chat_people_directory.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_person.dart';
import 'package:round_ai/features/chat/repository/chat_repository_impl.dart';
import 'package:round_ai/features/chat/repository/demo_chat_repository.dart';
import 'package:round_ai/features/chat/utils/chat_mention_utils.dart';
import 'package:round_ai/features/chat/widgets/chat_mention_composer.dart';

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
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mentions', () {
    test('mentionQueryAt finds active token', () {
      expect(mentionQueryAt('hi @Jo', 6)?.query, 'Jo');
      expect(mentionQueryAt('hi @Jo there', 12), isNull);
      expect(mentionQueryAt('email@x.com', 11), isNull);
    });

    testWidgets('composer inserts @FirstName', (WidgetTester tester) async {
      final TextEditingController c = TextEditingController();
      final FocusNode focus = FocusNode();
      final ChatPeopleDirectory people = ChatPeopleDirectory()
        ..upsert(const ChatPerson(id: 't1', displayName: 'Jordan Lee'));

      await tester.pumpWidget(
        _wrap(
          ChatMentionComposer(
            controller: c,
            focusNode: focus,
            enabled: true,
            onSend: () {},
            people: people,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '@Jo');
      await tester.pump();
      expect(find.text('Jordan Lee'), findsOneWidget);
      await tester.tap(find.text('Jordan Lee'));
      await tester.pump();
      expect(c.text, '@Jordan ');
    });
  });

  group('threads', () {
    test('partition counts replies from mixed list', () async {
      final FakeAdapter adapter = FakeAdapter((RequestOptions o) {
        if (o.path.endsWith('/messages')) {
          return FakeReply(200, <String, Object>{
            'messages': <Object>[
              <String, Object?>{
                'id': 'root',
                'channel_id': 'ch1',
                'sender_id': 'u1',
                'body': 'parent',
                'seq': 1,
                'parent_id': null,
                'deleted': false,
                'created_at': '2026-11-13T10:00:00.000Z',
              },
              <String, Object?>{
                'id': 'r1',
                'channel_id': 'ch1',
                'sender_id': 'u2',
                'body': 'reply',
                'seq': 2,
                'parent_id': 'root',
                'deleted': false,
                'created_at': '2026-11-13T10:01:00.000Z',
              },
            ],
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
      expect(cubit.state.items.length, 1);
      expect(cubit.state.items.single.message.id, 'root');
      expect(cubit.state.replyCount('root'), 1);
      await cubit.close();
    });

    test('demo thread send uses parent id', () async {
      final DemoChatRepository demo = DemoChatRepository();
      final Result<List<ChatMessage>> loaded = await demo.listMessages(
        'demo-general',
      );
      final String rootId = (loaded as Ok<List<ChatMessage>>).value.first.id;
      final Result<ChatMessage> sent = await demo.sendMessage(
        'demo-general',
        body: 'Thread reply',
        parentId: rootId,
      );
      expect((sent as Ok<ChatMessage>).value.parentId, rootId);
    });
  });

  group('search', () {
    test('debounced search returns demo hits', () async {
      final DemoChatRepository demo = DemoChatRepository();
      final ChatSearchCubit cubit = ChatSearchCubit(demo);
      cubit.onQueryChanged('handoff');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(cubit.state.results, isNotEmpty);
      expect(cubit.state.results.first.body.toLowerCase(), contains('handoff'));
      await cubit.close();
    });
  });

  group('people directory', () {
    test('matching filters by token', () {
      final ChatPeopleDirectory d = ChatPeopleDirectory()..seedDemo();
      expect(d.matchingMention('jor').single.mentionToken, 'Jordan');
    });
  });
}
