import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/evidence/models/evidence_result.dart';
import 'package:round_ai/features/evidence/screens/evidence_search_screen.dart';
import 'package:round_ai/features/learning/models/mcq_draft.dart';
import 'package:round_ai/features/learning/screens/teach_draft_screen.dart';
import 'package:round_ai/features/learning/screens/teach_queue_screen.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/signout/screens/signout_draft_screen.dart';
import 'package:round_ai/features/tasks/models/patient_task.dart';
import 'package:round_ai/features/tasks/screens/patient_tasks_screen.dart';
import 'package:round_ai/features/tasks/screens/team_tasks_screen.dart';
import 'package:round_ai/shared/widgets/app_input.dart';

import 'support/fake_ai_repository.dart';
import 'support/fake_f5.dart';
import 'support/fake_notes_problems.dart';

void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

VoidCallback? _onPressed(WidgetTester tester, String label) {
  return tester
      .widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (Widget w) => w is ButtonStyleButton,
          ),
        ),
      )
      .onPressed;
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  _wide(tester);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

FakeProblemsRepository _problemRepo() => FakeProblemsRepository(
  list: <Problem>[
    problem('c1', 'Heart failure', state: ProblemState.confirmed),
    problem('d1', 'Pneumonia', state: ProblemState.differential),
    problem('s1', 'Sepsis'),
  ],
);

void main() {
  group('evidence screen', () {
    Future<FakeEvidenceRepository> open(
      WidgetTester tester, {
      FakeEvidenceRepository? repo,
      bool aiOff = false,
      FakeProblemsRepository? problems,
    }) async {
      final FakeEvidenceRepository r = repo ?? FakeEvidenceRepository();
      await _pump(
        tester,
        EvidenceSearchScreen(
          patientId: 'p1',
          evidenceRepository: r,
          problemsRepository: problems ?? _problemRepo(),
          aiOff: aiOff,
          onOpen: (Uri uri) async => true,
        ),
      );
      return r;
    }

    testWidgets('lists only confirmed and differential problems', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(find.text('Heart failure'), findsOneWidget);
      expect(find.text('Pneumonia'), findsOneWidget);
      expect(find.text('Sepsis'), findsNothing);
      expect(find.text(FreeTextHint.text), findsOneWidget);
    });

    testWidgets('search is off until a problem or a topic is given', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(_onPressed(tester, 'Search evidence'), isNull);
      await tester.enterText(find.byType(TextField).first, 'SGLT2');
      await tester.pump();
      expect(_onPressed(tester, 'Search evidence'), isNotNull);
    });

    testWidgets('results are labelled as a draft and carry a PubMed link', (
      WidgetTester tester,
    ) async {
      final FakeEvidenceRepository repo = await open(tester);
      await tester.tap(find.text('Heart failure'));
      await tester.pump();
      await tester.tap(find.text('Search evidence'));
      await tester.pumpAndSettle();
      expect(repo.problems.single, 'c1');
      expect(find.text('AI draft · review required'), findsWidgets);
      expect(find.text('A trial of diuretics'), findsOneWidget);
      expect(find.text('PMID 111'), findsOneWidget);
      expect(find.textContaining('Abstract only'), findsOneWidget);
    });

    testWidgets('an empty result says so and shows no study', (
      WidgetTester tester,
    ) async {
      final FakeEvidenceRepository repo = FakeEvidenceRepository()
        ..reply = Ok<EvidenceResult>(evidenceResult());
      await open(tester, repo: repo);
      await tester.enterText(find.byType(TextField).first, 'Rare');
      await tester.pump();
      await tester.tap(find.text('Search evidence'));
      await tester.pumpAndSettle();
      expect(
        find.text('No relevant recent studies found in the searched sources.'),
        findsOneWidget,
      );
    });

    testWidgets('a failure uses our wording, not the server text', (
      WidgetTester tester,
    ) async {
      final FakeEvidenceRepository repo = FakeEvidenceRepository()
        ..reply = Err<EvidenceResult>(apiFail('query_not_safe', status: 422));
      await open(tester, repo: repo);
      await tester.enterText(find.byType(TextField).first, 'John Smith');
      await tester.pump();
      await tester.tap(find.text('Search evidence'));
      await tester.pumpAndSettle();
      expect(find.textContaining('raw server text'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('A trial of diuretics'), findsNothing);
    });

    testWidgets('a progress row with Cancel shows while searching', (
      WidgetTester tester,
    ) async {
      final Completer<Result<EvidenceResult>> wait =
          Completer<Result<EvidenceResult>>();
      final FakeEvidenceRepository repo = FakeEvidenceRepository()
        ..onSearch = () => wait.future;
      await open(tester, repo: repo);
      await tester.enterText(find.byType(TextField).first, 'x');
      await tester.pump();
      await tester.tap(find.text('Search evidence'));
      await tester.pump();
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(repo.lastToken!.isCancelled, isTrue);
      wait.complete(Err<EvidenceResult>(apiFail('cancelled')));
      await tester.pumpAndSettle();
    });

    testWidgets('with AI off the search is disabled and says why', (
      WidgetTester tester,
    ) async {
      await open(tester, aiOff: true);
      expect(find.text(evidenceAiOffMessage), findsOneWidget);
      expect(_onPressed(tester, 'Search evidence'), isNull);
    });
  });

  group('teach screen', () {
    Future<FakeTeachRepository> open(
      WidgetTester tester, {
      FakeTeachRepository? repo,
      bool aiOff = false,
    }) async {
      final FakeTeachRepository r = repo ?? FakeTeachRepository();
      await _pump(
        tester,
        TeachDraftScreen(
          patientId: 'p1',
          teachRepository: r,
          problemsRepository: _problemRepo(),
          aiOff: aiOff,
        ),
      );
      return r;
    }

    Future<void> ask(WidgetTester tester) async {
      await tester.tap(find.text('Heart failure'));
      await tester.pumpAndSettle();
    }

    testWidgets('only a confirmed problem is offered', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(find.text('Heart failure'), findsOneWidget);
      expect(find.text('Pneumonia'), findsNothing);
      expect(find.text('Review queue'), findsOneWidget);
    });

    testWidgets('an unreviewed question is labelled and gives no answer', (
      WidgetTester tester,
    ) async {
      final FakeTeachRepository repo = FakeTeachRepository()
        ..generated = Ok<McqDraft>(mcqDraft(withKey: true));
      await open(tester, repo: repo);
      await ask(tester);
      expect(find.text(unreviewedQuestionLabel), findsOneWidget);
      expect(find.text('A 72-year-old with dyspnea.'), findsOneWidget);
      for (final String o in <String>[
        'Alpha',
        'Bravo',
        'Charlie',
        'Delta',
        'Echo',
      ]) {
        expect(find.text(o), findsOneWidget);
      }
      // A key on the draft is never shown before the submit.
      expect(find.textContaining('Leaked explanation'), findsNothing);
      expect(find.text('Correct.'), findsNothing);
      expect(find.textContaining('The keyed answer is'), findsNothing);
      expect(_onPressed(tester, 'Submit answer'), isNull);
    });

    testWidgets('submitting reveals the key, explanations and references', (
      WidgetTester tester,
    ) async {
      final FakeTeachRepository repo = await open(tester);
      await ask(tester);
      await tester.tap(find.text('Alpha'));
      await tester.pump();
      expect(_onPressed(tester, 'Submit answer'), isNotNull);
      await tester.tap(find.text('Submit answer'));
      await tester.pumpAndSettle();
      expect(repo.answers, <int>[0]);
      expect(find.text('The keyed answer is C.'), findsOneWidget);
      expect(
        find.textContaining('Charlie is keyed because of volume overload.'),
        findsOneWidget,
      );
      expect(find.textContaining('Alpha is wrong.'), findsOneWidget);
      expect(find.text('• PMID 123'), findsOneWidget);
      expect(find.text('Another question'), findsOneWidget);
    });

    testWidgets('a right choice says Correct.', (WidgetTester tester) async {
      await open(tester);
      await ask(tester);
      await tester.tap(find.text('Charlie'));
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pumpAndSettle();
      expect(find.text('Correct.'), findsOneWidget);
    });

    testWidgets('report issue sends the typed reason', (
      WidgetTester tester,
    ) async {
      final FakeTeachRepository repo = await open(tester);
      await ask(tester);
      await tester.tap(find.text('Report issue'));
      await tester.pumpAndSettle();
      expect(find.text(FreeTextHint.text), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Two options are right');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(repo.reports, <String>['Two options are right']);
      expect(find.text('Issue reported for this question.'), findsOneWidget);
    });

    testWidgets('a failed generate uses our wording and can retry', (
      WidgetTester tester,
    ) async {
      final FakeTeachRepository repo = FakeTeachRepository()
        ..generated = Err<McqDraft>(apiFail('ai_unavailable', status: 503));
      await open(tester, repo: repo);
      await ask(tester);
      expect(find.textContaining('raw server text'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repo.keys, hasLength(2));
      expect(repo.keys[1], repo.keys[0]);
    });

    testWidgets('with AI off no question can be made', (
      WidgetTester tester,
    ) async {
      final FakeTeachRepository repo = await open(tester, aiOff: true);
      expect(find.text(teachAiOffMessage), findsOneWidget);
      await tester.tap(find.text('Heart failure'));
      await tester.pumpAndSettle();
      expect(repo.keys, isEmpty);
    });
  });

  group('teach review queue', () {
    testWidgets('shows the unreviewed question and marks it reviewed', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository ai = FakeAiRepository();
      await _pump(
        tester,
        TeachQueueScreen(
          patientId: 'p1',
          teachRepository: FakeTeachRepository(),
          aiRepository: ai,
        ),
      );
      expect(find.text('AI-generated, not yet reviewed'), findsOneWidget);
      expect(find.text('Mark reviewed'), findsOneWidget);
      await tester.tap(find.text('Mark reviewed'));
      await tester.pumpAndSettle();
      expect(ai.reviewed_, <String>['q1']);
      expect(find.text('No questions are waiting for review.'), findsOneWidget);
    });

    testWidgets('an empty queue says so', (WidgetTester tester) async {
      await _pump(
        tester,
        TeachQueueScreen(
          patientId: 'p1',
          teachRepository: FakeTeachRepository()
            ..queue = const Ok<List<McqDraft>>(<McqDraft>[]),
          aiRepository: FakeAiRepository(),
        ),
      );
      expect(find.text('No questions are waiting for review.'), findsOneWidget);
    });
  });

  group('patient tasks screen', () {
    Future<FakeTasksRepository> open(
      WidgetTester tester, {
      FakeTasksRepository? repo,
      List<String> plan = const <String>['Diurese'],
      bool aiOff = false,
    }) async {
      final FakeTasksRepository r = repo ?? FakeTasksRepository();
      await _pump(
        tester,
        PatientTasksScreen(
          patientId: 'p1',
          tasksRepository: r,
          patientRepository: FakePatientRepository(plan: plan),
          aiOff: aiOff,
        ),
      );
      return r;
    }

    testWidgets(
      'proposed tasks sit apart from open ones, labelled as a draft',
      (WidgetTester tester) async {
        await open(
          tester,
          repo: FakeTasksRepository()
            ..tasks = <PatientTask>[
              task('1', TaskStatus.proposed),
              task('2', TaskStatus.open),
              task('3', TaskStatus.completed),
            ],
        );
        expect(find.text('Proposed'), findsOneWidget);
        expect(find.text('AI draft · review required'), findsOneWidget);
        expect(find.text('Task 1'), findsOneWidget);
        expect(find.text('Task 2'), findsOneWidget);
        expect(find.text('Task 3'), findsOneWidget);
        expect(find.text('Accept'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);
        // No owner or due time is made up.
        expect(find.textContaining('Unassigned'), findsWidgets);
        expect(find.textContaining('No due time'), findsWidgets);
      },
    );

    testWidgets('without a plan proposing is replaced by a call to add one', (
      WidgetTester tester,
    ) async {
      final FakeTasksRepository repo = await open(
        tester,
        plan: const <String>[],
      );
      expect(find.text(noPlanMessage), findsOneWidget);
      expect(find.text('Add plan'), findsOneWidget);
      expect(repo.proposeCalls, 0);
    });

    testWidgets('propose from plan shows the proposals', (
      WidgetTester tester,
    ) async {
      final FakeTasksRepository repo = FakeTasksRepository();
      await open(tester, repo: repo);
      repo.tasks = <PatientTask>[task('9', TaskStatus.proposed)];
      repo.proposeReply = Ok<List<PatientTask>>(<PatientTask>[
        task('9', TaskStatus.proposed),
      ]);
      await tester.tap(find.text('Propose tasks from plan'));
      await tester.pumpAndSettle();
      expect(repo.proposeCalls, 1);
      expect(find.text('Task 9'), findsOneWidget);
      expect(find.text('Proposed'), findsOneWidget);
    });

    testWidgets('proposing nothing says so', (WidgetTester tester) async {
      await open(tester);
      await tester.tap(find.text('Propose tasks from plan'));
      await tester.pumpAndSettle();
      expect(
        find.text('No tasks were proposed from the plan.'),
        findsOneWidget,
      );
    });

    testWidgets('accept asks for owner and due time, both optional', (
      WidgetTester tester,
    ) async {
      final FakeTasksRepository repo = await open(
        tester,
        repo: FakeTasksRepository()
          ..tasks = <PatientTask>[task('1', TaskStatus.proposed)],
      );
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(find.text('Accept this task'), findsOneWidget);
      expect(
        find.text('Left blank, the task stays unassigned.'),
        findsOneWidget,
      );
      // Both left blank: accepted with neither.
      await tester.tap(find.widgetWithText(TextButton, 'Accept'));
      await tester.pumpAndSettle();
      expect(repo.accepted, <String>['1']);
      expect(repo.acceptDetails.single, (null, null));
    });

    testWidgets('dismiss removes nothing locally, it asks the backend', (
      WidgetTester tester,
    ) async {
      final FakeTasksRepository repo = await open(
        tester,
        repo: FakeTasksRepository()
          ..tasks = <PatientTask>[task('1', TaskStatus.proposed)],
      );
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(repo.dismissed, <String>['1']);
    });

    testWidgets('add task takes a title and an optional owner', (
      WidgetTester tester,
    ) async {
      final FakeTasksRepository repo = await open(tester);
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      expect(find.text('Add a task'), findsOneWidget);
      expect(find.text(FreeTextHint.text), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'Call family');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pumpAndSettle();
      expect(repo.added, <String>['Call family']);
    });

    testWidgets('a failed load shows a retry', (WidgetTester tester) async {
      final FakeTasksRepository repo = FakeTasksRepository()
        ..listReply = Err<List<PatientTask>>(apiFail('network_error'));
      await open(tester, repo: repo);
      expect(find.text('Tasks could not be loaded.'), findsOneWidget);
      repo.listReply = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Tasks could not be loaded.'), findsNothing);
    });

    testWidgets('with AI off proposing is off and says why', (
      WidgetTester tester,
    ) async {
      await open(tester, aiOff: true);
      expect(find.text(tasksAiOffMessage), findsOneWidget);
      expect(_onPressed(tester, 'Propose tasks from plan'), isNull);
    });
  });

  group('team tasks screen', () {
    testWidgets('groups open tasks by patient with open and overdue counts', (
      WidgetTester tester,
    ) async {
      final DateTime past = DateTime.now().subtract(const Duration(days: 1));
      await _pump(
        tester,
        TeamTasksScreen(
          censusRepository: FakeCensusRepository(<PatientSummary>[
            patientRow('a', openTasks: 2),
            patientRow('b'),
          ]),
          tasksRepository: FakeTasksRepository()
            ..byPatient = <String, List<PatientTask>>{
              'a': <PatientTask>[
                task('1', TaskStatus.open, patientId: 'a', dueAt: past),
                task('2', TaskStatus.open, patientId: 'a'),
              ],
            },
        ),
      );
      expect(find.text('Patient a · Room 50a'), findsOneWidget);
      expect(find.text('Task 1'), findsOneWidget);
      expect(find.text('Task 2'), findsOneWidget);
      expect(find.text('Overdue'), findsWidgets);
      expect(find.textContaining('Room 50b'), findsNothing);
    });

    testWidgets('an empty team says so', (WidgetTester tester) async {
      await _pump(
        tester,
        TeamTasksScreen(
          censusRepository: FakeCensusRepository(<PatientSummary>[
            patientRow('a'),
          ]),
          tasksRepository: FakeTasksRepository(),
        ),
      );
      expect(
        find.text('No open tasks for this team. Add one from a patient.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed census shows a retry', (WidgetTester tester) async {
      await _pump(
        tester,
        TeamTasksScreen(
          censusRepository: FakeCensusRepository(<PatientSummary>[])
            ..fails = true,
          tasksRepository: FakeTasksRepository(),
        ),
      );
      expect(find.text('Tasks could not be loaded.'), findsOneWidget);
    });

    testWidgets('one patient failing keeps the rest and says so', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        TeamTasksScreen(
          censusRepository: FakeCensusRepository(<PatientSummary>[
            patientRow('a', openTasks: 1),
            patientRow('c', openTasks: 1),
          ]),
          tasksRepository: FakeTasksRepository()
            ..failingPatients = <String>{'a'}
            ..byPatient = <String, List<PatientTask>>{
              'c': <PatientTask>[task('3', TaskStatus.open, patientId: 'c')],
            },
        ),
      );
      expect(find.text('Task 3'), findsOneWidget);
      expect(
        find.textContaining('Tasks for 1 patient could not be loaded.'),
        findsOneWidget,
      );
    });
  });

  group('sign-out screen', () {
    Future<FakeSignOutRepository> open(
      WidgetTester tester, {
      FakeSignOutRepository? repo,
      FakeAiRepository? ai,
      bool aiOff = false,
    }) async {
      final FakeSignOutRepository r = repo ?? FakeSignOutRepository();
      await _pump(
        tester,
        SignOutDraftScreen(
          patientId: 'p1',
          signOutRepository: r,
          aiRepository: ai ?? FakeAiRepository(),
          aiOff: aiOff,
        ),
      );
      return r;
    }

    testWidgets('asks the clinician for contingencies and warns about names', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(find.text('Contingency instructions'), findsOneWidget);
      expect(find.textContaining('None are invented'), findsOneWidget);
      expect(find.text(FreeTextHint.text), findsOneWidget);
      expect(find.text('Add contingency'), findsOneWidget);
    });

    testWidgets('with none typed it still generates and lists them missing', (
      WidgetTester tester,
    ) async {
      final FakeSignOutRepository repo = await open(tester);
      await tester.tap(find.text('Generate draft'));
      await tester.pumpAndSettle();
      expect(repo.sent.single, isEmpty);
      expect(find.text('AI draft · review required'), findsWidgets);
      expect(find.textContaining('contingency instructions'), findsWidgets);
      expect(find.text('Regenerate draft'), findsOneWidget);
    });

    testWidgets('typed contingencies are sent exactly as typed', (
      WidgetTester tester,
    ) async {
      final FakeSignOutRepository repo = await open(tester);
      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'SBP below 90');
      await tester.enterText(fields.at(1), 'Call the senior');
      await tester.tap(find.text('Generate draft'));
      await tester.pumpAndSettle();
      expect(repo.sent.single.single.condition, 'SBP below 90');
      expect(repo.sent.single.single.action, 'Call the senior');
    });

    testWidgets('a half-filled row blocks generating and says why', (
      WidgetTester tester,
    ) async {
      final FakeSignOutRepository repo = await open(tester);
      await tester.enterText(find.byType(TextField).at(0), 'SBP below 90');
      await tester.tap(find.text('Generate draft'));
      await tester.pumpAndSettle();
      expect(repo.keys, isEmpty);
      expect(find.text(halfFilledContingencyMessage), findsOneWidget);
    });

    testWidgets('mark reviewed is blocked on an outdated draft', (
      WidgetTester tester,
    ) async {
      final FakeSignOutRepository repo = FakeSignOutRepository()
        ..reply = Ok<AiEnvelope>(signOutEnvelope(outdated: true));
      await open(tester, repo: repo);
      await tester.tap(find.text('Generate draft'));
      await tester.pumpAndSettle();
      expect(_onPressed(tester, 'Mark reviewed'), isNull);
    });

    testWidgets('mark reviewed works on a current draft', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository ai = FakeAiRepository();
      await open(tester, ai: ai);
      await tester.tap(find.text('Generate draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark reviewed'));
      await tester.pumpAndSettle();
      expect(ai.reviewed_, <String>['so1']);
    });

    testWidgets('a failure uses our wording and offers a retry', (
      WidgetTester tester,
    ) async {
      final FakeSignOutRepository repo = FakeSignOutRepository()
        ..reply = Err<AiEnvelope>(apiFail('ai_unavailable', status: 503));
      await open(tester, repo: repo);
      await tester.tap(find.text('Generate draft'));
      await tester.pumpAndSettle();
      expect(find.textContaining('raw server text'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repo.keys[1], repo.keys[0]);
    });

    testWidgets('with AI off generating is off and says why', (
      WidgetTester tester,
    ) async {
      await open(tester, aiOff: true);
      expect(find.text(signOutAiOffMessage), findsOneWidget);
      expect(_onPressed(tester, 'Generate draft'), isNull);
    });
  });
}
