import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_nav_extra.dart';
import 'package:round_ai/features/chat/models/chat_summary_draft.dart';
import 'package:round_ai/features/chat/repository/chat_repository_impl.dart';
import 'package:round_ai/features/chat/repository/demo_chat_repository.dart';
import 'package:round_ai/features/chat/screens/chat_channel_screen.dart';
import 'package:round_ai/features/chat/screens/chat_summary_draft_screen.dart';

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

ChatSummaryDraft _draft() {
  return ChatSummaryDraft.fromEnvelope(
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
        'channel_id': 'demo-patient-1',
        'bullets': <Object>[
          <String, Object>{
            'text': 'Imaging still pending.',
            'message_ids': <String>['m1'],
          },
        ],
        'open_questions': <String>['When is the read due?'],
        'missing_information': <String>['No contingency noted.'],
        'disclaimer': 'AI draft · review required. Not posted to the channel.',
      },
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('patient channel', () {
    test('demo resolves seeded patient id and auto-creates others', () async {
      final DemoChatRepository chat = DemoChatRepository();
      final Result<ChatChannel> seeded = await chat.patientChannel('p-509a');
      expect(seeded, isA<Ok<ChatChannel>>());
      final ChatChannel ch = (seeded as Ok<ChatChannel>).value;
      expect(ch.type, ChatChannelType.patient);
      expect(ch.patientId, 'p-509a');
      expect(ch.name, 'Room 509A');

      final Result<ChatChannel> created = await chat.patientChannel('p-412b');
      expect(created, isA<Ok<ChatChannel>>());
      expect((created as Ok<ChatChannel>).value.patientId, 'p-412b');
    });

    test('impl GET /patients/:id/channel', () async {
      final FakeAdapter adapter = FakeAdapter((RequestOptions o) {
        expect(o.method, 'GET');
        expect(o.path, '/patients/p1/channel');
        return FakeReply(200, <String, Object?>{
          'id': 'ch-p1',
          'team_id': 't1',
          'name': 'Room 1',
          'type': 'patient',
          'patient_id': 'p1',
          'archived': false,
          'unread': 0,
          'created_at': '2026-11-13T10:00:00.000Z',
        });
      });
      final ChatRepositoryImpl repo = ChatRepositoryImpl(
        await _client(adapter),
      );
      final Result<ChatChannel> result = await repo.patientChannel('p1');
      expect(result, isA<Ok<ChatChannel>>());
      expect((result as Ok<ChatChannel>).value.patientId, 'p1');
    });
  });

  group('summarize', () {
    test('demo summarize returns private draft bullets', () async {
      final DemoChatRepository chat = DemoChatRepository();
      final Result<ChatSummaryDraft> result = await chat.summarizeThread(
        'demo-patient-1',
        idempotencyKey: 'k1',
      );
      expect(result, isA<Ok<ChatSummaryDraft>>());
      final ChatSummaryDraft draft = (result as Ok<ChatSummaryDraft>).value;
      expect(draft.bullets, isNotEmpty);
      expect(draft.requiresReview, isTrue);
      expect(draft.disclaimer.toLowerCase(), contains('review'));
    });

    test('impl posts idempotency key and never mutates channel', () async {
      String? key;
      final FakeAdapter adapter = FakeAdapter((RequestOptions o) {
        expect(o.method, 'POST');
        expect(o.path, '/channels/ch1/summarize');
        key = o.headers['Idempotency-Key']?.toString();
        return FakeReply(200, <String, Object?>{
          'artifact_id': 'a1',
          'operation': 'summarize_chat_thread',
          'patient_id': '',
          'context_revision': 0,
          'status': 'draft',
          'review_state': 'draft',
          'outdated': false,
          'requires_review': true,
          'provider': 'x',
          'model': 'y',
          'prompt_version': '1',
          'generation_ms': 2,
          'created_at': '2026-11-13T10:00:00.000Z',
          'content': <String, Object?>{
            'channel_id': 'ch1',
            'bullets': <Object>[
              <String, Object>{'text': 'One bullet', 'message_ids': <String>[]},
            ],
            'open_questions': <Object>[],
            'missing_information': <Object>[],
            'disclaimer': 'AI draft · review required.',
          },
        });
      });
      final ChatRepositoryImpl repo = ChatRepositoryImpl(
        await _client(adapter),
      );
      final Result<ChatSummaryDraft> result = await repo.summarizeThread(
        'ch1',
        idempotencyKey: 'idem-42',
      );
      expect(key, 'idem-42');
      expect(result, isA<Ok<ChatSummaryDraft>>());
      expect((result as Ok<ChatSummaryDraft>).value.bullets.single.text, 'One bullet');
    });
  });

  group('UI', () {
    testWidgets('channel shows patient back-link and summarize menu', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ChatChannelScreen(
            channelId: 'demo-patient-1',
            title: 'Room 509A',
            channelType: ChatChannelType.patient,
            patientId: 'p-509a',
            patientLabel: 'Rosa Martinez · Room 509A',
            chatRepository: DemoChatRepository(),
            chatOff: false,
            currentUserId: 'demo',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rosa Martinez · Room 509A'), findsOneWidget);
      expect(find.text('View patient'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Summarize thread'), findsOneWidget);
    });

    testWidgets('summary draft shows review banner and copy', (
      WidgetTester tester,
    ) async {
      final List<MethodCall> calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          calls.add(call);
          return null;
        },
      );

      await tester.pumpWidget(
        _wrap(
          ChatSummaryDraftScreen(
            draft: _draft(),
            channelTitle: 'Room 509A',
          ),
        ),
      );
      expect(find.text('AI draft · review required'), findsWidgets);
      expect(find.text('Imaging still pending.'), findsOneWidget);
      expect(
        find.text('This draft is only for you. It was not posted to the channel.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Copy draft'));
      await tester.pump();
      expect(
        calls.any(
          (MethodCall c) =>
              c.method == 'Clipboard.setData' &&
              c.arguments.toString().contains('Imaging still pending'),
        ),
        isTrue,
      );
    });

    test('ChatChannelExtra carries patient fields outside the URL', () {
      const ChatChannelExtra extra = ChatChannelExtra(
        patientId: 'p-509a',
        patientLabel: 'Room 509A',
      );
      expect(extra.patientId, 'p-509a');
      expect(extra.patientLabel, 'Room 509A');
    });
  });
}
