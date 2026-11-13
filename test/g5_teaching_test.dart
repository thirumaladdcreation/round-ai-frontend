import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/learning/models/teaching_plan.dart';
import 'package:round_ai/features/learning/models/teaching_question.dart';
import 'package:round_ai/features/learning/models/teaching_reads.dart';
import 'package:round_ai/features/learning/repository/demo_teaching_repository.dart';
import 'package:round_ai/features/learning/repository/teaching_repository_impl.dart';
import 'package:round_ai/features/learning/screens/learning_screen.dart';
import 'package:round_ai/features/learning/screens/topic_quiz_screen.dart';
import 'package:round_ai/features/learning/screens/topic_reads_screen.dart';

import 'support/fake_adapter.dart';

Future<ApiClient> _client(FakeAdapter adapter) async {
  final SessionStore session = SessionStore(MemoryTokenStore());
  await session.save('tok', persist: false);
  return ApiClient(session: session, dio: fakeDio(adapter));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('teaching models', () {
    test('plan topics never require patient fields', () {
      final TeachingPlan plan = TeachingPlan.fromJson(<String, dynamic>{
        'date': '2026-11-13',
        'topics': <Object>[
          <String, Object>{
            'topic': 'Community acquired pneumonia',
            'topic_key': 'community acquired pneumonia',
            'count': 2,
            'confirmed': 1,
            'differential': 1,
          },
        ],
        'note': 'No patient identifiers are stored with the teaching plan.',
      });
      expect(plan.topics.single.topic, contains('pneumonia'));
      expect(plan.topics.single.count, 2);
    });

    test('filters non-learner-safe questions from bank response', () {
      final TeachingQuestionsResult r = TeachingQuestionsResult.fromJson(
        <String, dynamic>{
          'topic': 'AKI',
          'topic_key': 'aki',
          'bank_served': 1,
          'generated': 1,
          'questions': <Object>[
            <String, Object>{
              'mcq_id': 'ok1',
              'topic': 'AKI',
              'status': 'approved',
              'bank': true,
              'vignette': 'V',
              'question': 'Q?',
              'options': <String, String>{'A': 'one', 'B': 'two'},
              'learner_label': 'Approved bank question',
            },
            <String, Object>{
              'mcq_id': 'draft1',
              'topic': 'AKI',
              'status': 'ai_generated_unreviewed',
              'bank': false,
              'vignette': 'V2',
              'question': 'Q2?',
              'options': <String, String>{'A': 'a', 'B': 'b'},
              'learner_label': 'AI-generated (unreviewed).',
            },
            <String, Object>{
              'mcq_id': 'bad',
              'topic': 'AKI',
              'status': 'reported',
              'bank': true,
              'vignette': 'X',
              'question': 'Y',
              'options': <String, String>{'A': 'a'},
            },
          ],
        },
      );
      expect(r.questions.map((TeachingQuestion q) => q.mcqId), <String>[
        'ok1',
        'draft1',
      ]);
      expect(r.questions.any((TeachingQuestion q) => q.status == 'reported'), isFalse);
      expect(r.questions.last.isUnreviewed, isTrue);
    });

    test('curated high-yield label is reserved', () {
      final TeachingReads reads = TeachingReads.fromJson(<String, dynamic>{
        'topic': 'CAP',
        'topic_key': 'cap',
        'recent': <Object>[
          <String, Object>{
            'title': 'Recent',
            'pmid': '1',
            'label': 'Recent',
            'high_yield': false,
          },
        ],
        'older_high_design': <Object>[],
        'guidelines_pubmed': <Object>[
          <String, Object>{
            'title': 'Guideline',
            'pmid': '2',
            'label': 'Guideline',
            'high_yield': false,
          },
        ],
        'curated_high_yield': <Object>[
          <String, Object>{
            'title': 'Landmark',
            'pmid': '3',
            'label': curatedHighYieldLabel,
            'high_yield': true,
            'curated': true,
          },
        ],
      });
      expect(reads.curatedHighYield.single.highYield, isTrue);
      expect(reads.curatedHighYield.single.label, curatedHighYieldLabel);
      expect(reads.recent.single.highYield, isFalse);
      expect(reads.guidelinesPubmed.single.highYield, isFalse);
    });
  });

  group('TeachingRepositoryImpl', () {
    test('loadPlan GETs /teaching/plan', () async {
      final FakeAdapter a = FakeAdapter((RequestOptions o) {
        expect(o.path, '/teaching/plan');
        return FakeReply(200, <String, Object>{
          'date': '2026-11-13',
          'topics': <Object>[],
        });
      });
      final TeachingRepositoryImpl repo = TeachingRepositoryImpl(
        await _client(a),
      );
      final Result<TeachingPlan> r = await repo.loadPlan();
      expect(r, isA<Ok<TeachingPlan>>());
    });

    test('loadQuestions filters and parses options map', () async {
      final FakeAdapter a = FakeAdapter((RequestOptions o) {
        expect(o.path, '/teaching/questions');
        expect(o.queryParameters['topic'], 'AKI');
        expect(o.queryParameters['allow_generate'], isNull);
        return FakeReply(200, <String, Object>{
          'topic': 'AKI',
          'topic_key': 'aki',
          'bank_served': 1,
          'generated': 0,
          'questions': <Object>[
            <String, Object>{
              'mcq_id': 'q1',
              'topic': 'AKI',
              'status': 'approved',
              'bank': true,
              'question': 'Next step?',
              'options': <String, String>{'A': 'Fluids', 'B': 'Dialysis'},
              'learner_label': 'Approved bank question',
            },
          ],
        });
      });
      final TeachingRepositoryImpl repo = TeachingRepositoryImpl(
        await _client(a),
      );
      final Result<TeachingQuestionsResult> r = await repo.loadQuestions(
        topic: 'AKI',
      );
      final TeachingQuestion q =
          (r as Ok<TeachingQuestionsResult>).value.questions.single;
      expect(q.options.first.letter, 'A');
      expect(q.options.first.text, 'Fluids');
    });

    test('answer posts choice letter', () async {
      final FakeAdapter a = FakeAdapter((RequestOptions o) {
        expect(o.path, '/mcq/q1/answer');
        expect(o.data, containsPair('choice', 'B'));
        return FakeReply(200, <String, Object>{
          'correct': true,
          'correct_answer': 'B',
          'explanation': 'Yes',
          'option_explanations': <String, String>{
            'A': 'No',
            'B': 'Yes',
          },
        });
      });
      final TeachingRepositoryImpl repo = TeachingRepositoryImpl(
        await _client(a),
      );
      final Result<McqAnswerResult> r = await repo.answer(
        mcqId: 'q1',
        choice: 'b',
      );
      expect((r as Ok<McqAnswerResult>).value.correct, isTrue);
    });

    test('loadQuestion maps not_approved for reported', () async {
      final FakeAdapter a = FakeAdapter(
        (RequestOptions o) => FakeReply(403, <String, Object>{
          'error': <String, String>{
            'code': 'not_approved',
            'message': 'not for learners',
          },
        }),
      );
      final TeachingRepositoryImpl repo = TeachingRepositoryImpl(
        await _client(a),
      );
      final Result<TeachingQuestion> r = await repo.loadQuestion('x');
      expect(r, isA<Err<TeachingQuestion>>());
      final Failure failure = (r as Err<TeachingQuestion>).failure;
      expect(failure, isA<ApiFailure>());
      expect((failure as ApiFailure).error.kind, ApiErrorKind.notApproved);
    });
  });

  group('demo teaching UI', () {
    testWidgets('Learn tab lists topics without patient names', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LearningScreen(repository: DemoTeachingRepository()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Today’s topics'), findsOneWidget);
      expect(find.textContaining('No patient names'), findsOneWidget);
      expect(find.text('Rosa Martinez'), findsNothing);
      expect(find.text('Guideline updates'), findsOneWidget);
      expect(
        find.textContaining('No approved guideline updates'),
        findsOneWidget,
      );
    });

    testWidgets('quiz shows report and submit for bank question', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: TopicQuizScreen(
            topic: 'Acute kidney injury',
            repository: DemoTeachingRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Include AI-generated drafts'), findsOneWidget);
      expect(find.text('Report issue'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
    });

    test('allow_generate adds labeled unreviewed draft in demo repo', () async {
      final DemoTeachingRepository repo = DemoTeachingRepository();
      final Result<TeachingQuestionsResult> bankOnly = await repo.loadQuestions(
        topic: 'AKI',
        count: 2,
      );
      expect(
        (bankOnly as Ok<TeachingQuestionsResult>).value.questions
            .every((TeachingQuestion q) => q.bank),
        isTrue,
      );
      final Result<TeachingQuestionsResult> withGen = await repo.loadQuestions(
        topic: 'AKI',
        count: 2,
        allowGenerate: true,
      );
      final List<TeachingQuestion> qs =
          (withGen as Ok<TeachingQuestionsResult>).value.questions;
      expect(qs.any((TeachingQuestion q) => q.isUnreviewed), isTrue);
      expect(
        qs.any(
          (TeachingQuestion q) =>
              q.learnerLabel.toLowerCase().contains('unreviewed'),
        ),
        isTrue,
      );
    });

    testWidgets('reads sections use curated high-yield only there', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: TopicReadsScreen(
            topic: 'CAP',
            repository: DemoTeachingRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recent studies'), findsOneWidget);
      expect(find.text('Older high-design evidence'), findsOneWidget);
      expect(find.text('Guidelines'), findsOneWidget);
      // Section title + item label both use the curated wording.
      expect(find.text(curatedHighYieldLabel), findsWidgets);
      expect(find.text('Save'), findsWidgets);
    });

    test('reported questions are not returned by demo loadQuestions after report',
        () async {
      final DemoTeachingRepository repo = DemoTeachingRepository();
      final Result<TeachingQuestionsResult> first = await repo.loadQuestions(
        topic: 'AKI',
      );
      final String id =
          (first as Ok<TeachingQuestionsResult>).value.questions.first.mcqId;
      await repo.report(mcqId: id, note: 'bad');
      final Result<TeachingQuestion> again = await repo.loadQuestion(id);
      expect(again, isA<Err<TeachingQuestion>>());
    });
  });
}
