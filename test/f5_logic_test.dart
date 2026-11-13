import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/evidence/bloc/evidence_cubit.dart';
import 'package:round_ai/features/evidence/models/evidence_result.dart';
import 'package:round_ai/features/evidence/repository/evidence_repository_impl.dart';
import 'package:round_ai/features/learning/bloc/mcq_queue_cubit.dart';
import 'package:round_ai/features/learning/bloc/teach_cubit.dart';
import 'package:round_ai/features/learning/models/mcq_draft.dart';
import 'package:round_ai/features/learning/repository/teach_repository_impl.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/signout/bloc/signout_cubit.dart';
import 'package:round_ai/features/signout/models/contingency.dart';
import 'package:round_ai/features/signout/repository/signout_repository_impl.dart';
import 'package:round_ai/features/tasks/bloc/patient_tasks_cubit.dart';
import 'package:round_ai/features/tasks/bloc/team_tasks_cubit.dart';
import 'package:round_ai/features/tasks/models/patient_task.dart';
import 'package:round_ai/features/tasks/repository/tasks_repository_impl.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';

import 'support/fake_adapter.dart';
import 'support/fake_ai_repository.dart';
import 'support/fake_f5.dart';
import 'support/fake_notes_problems.dart';

Future<ApiClient> _client(FakeAdapter adapter) async {
  final SessionStore session = SessionStore(MemoryTokenStore());
  await session.save('tok', persist: false);
  return ApiClient(session: session, dio: fakeDio(adapter));
}

Map<String, Object> _envelopeBody(Map<String, Object> content) =>
    <String, Object>{
      'artifact_id': 'a1',
      'operation': 'x',
      'patient_id': 'p1',
      'context_revision': 2,
      'status': 'draft',
      'review_state': 'draft',
      'outdated': false,
      'created_at': '2026-11-12T09:00:00Z',
      'content': content,
    };

List<Problem> _problems() => <Problem>[
  problem('c1', 'Heart failure', state: ProblemState.confirmed),
  problem('d1', 'Pneumonia', state: ProblemState.differential),
  problem('s1', 'Sepsis', state: ProblemState.suggested),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('evidence', () {
    test(
      'only confirmed and differential problems can start a search',
      () async {
        final EvidenceCubit cubit = EvidenceCubit(
          FakeEvidenceRepository(),
          FakeProblemsRepository(list: _problems()),
          'p1',
        );
        await cubit.loadProblems();
        expect(cubit.state.problems.map((Problem p) => p.id), <String>[
          'c1',
          'd1',
        ]);
        await cubit.close();
      },
    );

    test('nothing chosen and nothing typed sends nothing', () async {
      final FakeEvidenceRepository repo = FakeEvidenceRepository();
      final EvidenceCubit cubit = EvidenceCubit(
        repo,
        FakeProblemsRepository(),
        'p1',
      );
      await cubit.search(topic: '   ');
      expect(repo.keys, isEmpty);
      await cubit.close();
    });

    test('a problem search sends the problem and no topic', () async {
      final FakeEvidenceRepository repo = FakeEvidenceRepository();
      final EvidenceCubit cubit = EvidenceCubit(
        repo,
        FakeProblemsRepository(list: _problems()),
        'p1',
      );
      await cubit.loadProblems();
      await cubit.search(problemId: 'c1', topic: 'ignored');
      expect(repo.problems.single, 'c1');
      expect(repo.topics.single, isNull);
      expect(cubit.state.searchedLabel, 'Heart failure');
      expect(cubit.state.result!.cards, hasLength(1));
      expect(cubit.state.aiState, AiState.draftReady);
      await cubit.close();
    });

    test('an empty result is "no evidence", never filled in', () async {
      final FakeEvidenceRepository repo = FakeEvidenceRepository()
        ..reply = Ok<EvidenceResult>(evidenceResult());
      final EvidenceCubit cubit = EvidenceCubit(
        repo,
        FakeProblemsRepository(),
        'p1',
      );
      await cubit.search(topic: 'Rare thing');
      expect(cubit.state.result!.isEmpty, isTrue);
      expect(cubit.state.aiState, AiState.noEvidence);
      await cubit.close();
    });

    test('a retry keeps the key, a new topic gets a new one', () async {
      final FakeEvidenceRepository repo = FakeEvidenceRepository()
        ..reply = Err<EvidenceResult>(apiFail('ai_unavailable', status: 503));
      final EvidenceCubit cubit = EvidenceCubit(
        repo,
        FakeProblemsRepository(),
        'p1',
      );
      await cubit.search(topic: 'sglt2');
      expect(cubit.state.error, isNotNull);
      await cubit.retry();
      expect(repo.keys[1], repo.keys[0]);
      await cubit.search(topic: 'beta blocker');
      expect(repo.keys[2], isNot(repo.keys[0]));
      await cubit.close();
    });

    test('a query that is not safe is not retried with the same key', () async {
      final FakeEvidenceRepository repo = FakeEvidenceRepository()
        ..reply = Err<EvidenceResult>(apiFail('query_not_safe', status: 422));
      final EvidenceCubit cubit = EvidenceCubit(
        repo,
        FakeProblemsRepository(),
        'p1',
      );
      await cubit.search(topic: 'John Smith 1/2/1950');
      expect(cubit.state.error!.kind, ApiErrorKind.querySafety);
      await cubit.search(topic: 'John Smith 1/2/1950');
      expect(repo.keys[1], isNot(repo.keys[0]));
      await cubit.close();
    });

    test('cancel stops the call and leaves no error', () async {
      final Completer<Result<EvidenceResult>> wait =
          Completer<Result<EvidenceResult>>();
      final FakeEvidenceRepository repo = FakeEvidenceRepository()
        ..onSearch = () => wait.future;
      final EvidenceCubit cubit = EvidenceCubit(
        repo,
        FakeProblemsRepository(),
        'p1',
      );
      final Future<void> run = cubit.search(topic: 'x');
      expect(cubit.state.searching, isTrue);
      cubit.cancel();
      expect(repo.lastToken!.isCancelled, isTrue);
      wait.complete(Err<EvidenceResult>(apiFail('cancelled')));
      await run;
      expect(cubit.state.searching, isFalse);
      await cubit.close();
    });

    test('repository sends only the topic or the problem', () async {
      final FakeAdapter a = FakeAdapter(
        (RequestOptions o) => FakeReply(
          200,
          _envelopeBody(<String, Object>{
            'evidence': <Object>[studyJson()],
            'retrieval': <String, Object>{
              'sources': <String>['PubMed'],
            },
          }),
        ),
      );
      final EvidenceRepositoryImpl repo = EvidenceRepositoryImpl(
        await _client(a),
      );
      await repo.search('p1', topic: ' sglt2 ', idempotencyKey: 'k1');
      await repo.search('p1', problemId: 'c1', idempotencyKey: 'k2');
      expect(a.requests[0].path, '/patients/p1/evidence');
      expect(a.requests[0].data, <String, String>{'topic': 'sglt2'});
      expect(a.requests[0].headers[IdempotencyKey.header], 'k1');
      expect(a.requests[1].data, <String, String>{'problem_id': 'c1'});
    });

    test('cards expose a PubMed link only when there is a PMID', () {
      final EvidenceResult r = evidenceResult(
        studies: <Map<String, dynamic>>[
          studyJson(pmid: '999'),
          <String, dynamic>{'id': 'x', 'title': 'No PMID'},
        ],
      );
      expect(
        r.cards.first.pubmedUri.toString(),
        'https://pubmed.ncbi.nlm.nih.gov/999/',
      );
      expect(r.cards.last.pubmedUri, isNull);
      expect(r.cards.last.accessLevel, 'Source not available');
    });
  });

  group('teach', () {
    TeachCubit cubit(FakeTeachRepository repo) =>
        TeachCubit(repo, FakeProblemsRepository(list: _problems()), 'p1');

    test('only confirmed problems can make a question', () async {
      final TeachCubit c = cubit(FakeTeachRepository());
      await c.loadProblems();
      expect(c.state.problems.map((Problem p) => p.id), <String>['c1']);
      await c.close();
    });

    test('a question that arrives with a key does not reveal it', () async {
      final FakeTeachRepository repo = FakeTeachRepository()
        ..generated = Ok<McqDraft>(mcqDraft(withKey: true));
      final TeachCubit c = cubit(repo);
      await c.generate('c1');
      expect(c.state.draft, isNotNull);
      expect(c.state.reveal, isNull);
      expect(c.state.answered, isFalse);
      await c.close();
    });

    test('submit needs a choice, and no answer call before it', () async {
      final FakeTeachRepository repo = FakeTeachRepository();
      final TeachCubit c = cubit(repo);
      await c.generate('c1');
      await c.submit();
      expect(repo.answerCalls, 0);
      c.select(1);
      expect(c.state.canSubmit, isTrue);
      await c.submit();
      expect(repo.answers, <int>[1]);
      expect(c.state.reveal!.correctIndex, 2);
      expect(c.state.reveal!.references, <String>['PMID 123']);
      await c.close();
    });

    test('the choice is locked after the answer', () async {
      final TeachCubit c = cubit(FakeTeachRepository());
      await c.generate('c1');
      c.select(0);
      await c.submit();
      c.select(3);
      expect(c.state.selected, 0);
      await c.close();
    });

    test('an out of range option is ignored', () async {
      final TeachCubit c = cubit(FakeTeachRepository());
      await c.generate('c1');
      c.select(9);
      expect(c.state.selected, isNull);
      await c.close();
    });

    test('a reply without a keyed answer is an error, not a guess', () async {
      final FakeTeachRepository repo = FakeTeachRepository()
        ..answered = const Ok<Map<String, dynamic>>(<String, dynamic>{});
      final TeachCubit c = cubit(repo);
      await c.generate('c1');
      c.select(0);
      await c.submit();
      expect(c.state.reveal, isNull);
      expect(c.state.answerError, isNotNull);
      await c.close();
    });

    test('per-option explanations map around the keyed answer', () {
      const McqReveal four = McqReveal(
        correctIndex: 2,
        optionExplanations: <String>['a', 'b', 'd', 'e'],
      );
      expect(four.explanationFor(0, 5), 'a');
      expect(four.explanationFor(2, 5), isNull);
      expect(four.explanationFor(3, 5), 'd');
      expect(four.explanationFor(4, 5), 'e');
      const McqReveal five = McqReveal(
        correctIndex: 1,
        optionExplanations: <String>['a', 'b', 'c', 'd', 'e'],
      );
      expect(five.explanationFor(1, 5), 'b');
    });

    test('the key is kept for a retry and reset for another problem', () async {
      final FakeTeachRepository repo = FakeTeachRepository()
        ..generated = Err<McqDraft>(apiFail('ai_unavailable', status: 503));
      final TeachCubit c = cubit(repo);
      await c.generate('c1');
      await c.retry();
      expect(repo.keys[1], repo.keys[0]);
      await c.generate('d1');
      expect(repo.keys[2], isNot(repo.keys[0]));
      await c.close();
    });

    test('an unreviewed question says so, a reviewed one does not', () {
      expect(mcqDraft().isReviewed, isFalse);
      expect(mcqDraft(status: 'reviewed').isReviewed, isTrue);
      expect(mcqDraft(review: 'reviewed').isReviewed, isTrue);
    });

    test('report sends the reason once', () async {
      final FakeTeachRepository repo = FakeTeachRepository();
      final TeachCubit c = cubit(repo);
      await c.generate('c1');
      await c.report('Wrong key');
      await c.report('Wrong key');
      expect(repo.reports, <String>['Wrong key']);
      expect(c.state.reported, isTrue);
      await c.close();
    });

    test('a failed report can be sent again', () async {
      final FakeTeachRepository repo = FakeTeachRepository()
        ..reported = Err<void>(apiFail('network_error'));
      final TeachCubit c = cubit(repo);
      await c.generate('c1');
      await c.report('Wrong key');
      expect(c.state.reported, isFalse);
      expect(c.state.reportError, isNotNull);
      repo.reported = const Ok<void>(null);
      await c.report('Wrong key');
      expect(c.state.reported, isTrue);
      await c.close();
    });

    test('next goes back to choosing a problem', () async {
      final TeachCubit c = cubit(FakeTeachRepository());
      await c.loadProblems();
      await c.generate('c1');
      c.next();
      expect(c.state.draft, isNull);
      expect(c.state.problems, isNotEmpty);
      await c.close();
    });

    test(
      'repository answer posts the choice and the queue lists drafts',
      () async {
        final FakeAdapter a = FakeAdapter((RequestOptions o) {
          if (o.path.endsWith('/answer')) {
            return const FakeReply(200, <String, Object>{'correct_index': 1});
          }
          return const FakeReply(200, <String, Object>{
            'artifacts': <Object>[],
          });
        });
        final TeachRepositoryImpl repo = TeachRepositoryImpl(await _client(a));
        final Result<Map<String, dynamic>> r = await repo.answer(
          'q1',
          selectedIndex: 3,
        );
        expect((r as Ok<Map<String, dynamic>>).value['correct_index'], 1);
        expect(a.requests.first.path, '/mcq/q1/answer');
        expect(a.requests.first.data, <String, String>{'choice': 'D'});
      },
    );

    test('the review queue lists unreviewed questions and marks one', () async {
      final FakeTeachRepository repo = FakeTeachRepository()
        ..queue = Ok<List<McqDraft>>(<McqDraft>[
          mcqDraft(id: 'q1', withKey: true),
          mcqDraft(id: 'q2', withKey: true, status: 'reviewed'),
        ]);
      final FakeAiRepository ai = FakeAiRepository();
      final McqQueueCubit q = McqQueueCubit(repo, ai, 'p1');
      await q.load();
      expect(q.state.items.map((McqDraft d) => d.mcq.id), <String>['q1']);
      await q.markReviewed(q.state.items.first);
      expect(ai.reviewed_, <String>['q1']);
      expect(q.state.items, isEmpty);
      await q.close();
    });
  });

  group('tasks', () {
    final DateTime now = DateTime.utc(2026, 11, 12, 12);

    PatientTasksCubit cubit(
      FakeTasksRepository tasks, {
      List<String> plan = const <String>['Diurese'],
    }) => PatientTasksCubit(tasks, FakePatientRepository(plan: plan), 'p1');

    test('proposed tasks are kept apart from open ones', () async {
      final FakeTasksRepository repo = FakeTasksRepository()
        ..tasks = <PatientTask>[
          task('1', TaskStatus.proposed),
          task('2', TaskStatus.open),
          task('3', TaskStatus.completed),
          task('4', TaskStatus.dismissed),
        ];
      final PatientTasksCubit c = cubit(repo);
      await c.load();
      expect(c.state.proposed.map((PatientTask t) => t.id), <String>['1']);
      expect(c.state.open.map((PatientTask t) => t.id), <String>['2']);
      expect(c.state.completed.map((PatientTask t) => t.id), <String>['3']);
      await c.close();
    });

    test('propose is blocked without a saved plan', () async {
      final FakeTasksRepository repo = FakeTasksRepository();
      final PatientTasksCubit c = cubit(repo, plan: const <String>[]);
      await c.load();
      expect(c.state.hasPlan, isFalse);
      expect(c.state.canPropose, isFalse);
      await c.propose();
      expect(repo.proposeCalls, 0);
      await c.close();
    });

    test('propose adds proposals, never open tasks', () async {
      final FakeTasksRepository repo = FakeTasksRepository()
        ..proposeReply = Ok<List<PatientTask>>(<PatientTask>[
          task('9', TaskStatus.proposed),
        ]);
      final PatientTasksCubit c = cubit(repo);
      await c.load();
      repo.tasks = <PatientTask>[task('9', TaskStatus.proposed)];
      await c.propose();
      expect(c.state.proposed, hasLength(1));
      expect(c.state.open, isEmpty);
      expect(c.state.proposedCount, 1);
      await c.close();
    });

    test('a retried propose keeps its key, a done one does not', () async {
      final FakeTasksRepository repo = FakeTasksRepository()
        ..proposeReply = Err<List<PatientTask>>(
          apiFail('ai_unavailable', status: 503),
        );
      final PatientTasksCubit c = cubit(repo);
      await c.load();
      await c.propose();
      await c.propose();
      expect(repo.proposeKeys[1], repo.proposeKeys[0]);
      repo.proposeReply = const Ok<List<PatientTask>>(<PatientTask>[]);
      await c.propose();
      await c.propose();
      expect(repo.proposeKeys[3], isNot(repo.proposeKeys[2]));
      await c.close();
    });

    test('accept passes the optional owner and due time', () async {
      final FakeTasksRepository repo = FakeTasksRepository();
      final PatientTasksCubit c = cubit(repo);
      await c.load();
      await c.accept(
        task('1', TaskStatus.proposed),
        owner: 'Dr Rao',
        dueAt: now,
      );
      await c.accept(task('2', TaskStatus.proposed));
      expect(repo.acceptDetails[0], ('Dr Rao', now));
      expect(repo.acceptDetails[1], (null, null));
      expect(c.state.changes, 2);
      await c.close();
    });

    test('dismiss, complete and add go to the backend and reload', () async {
      final FakeTasksRepository repo = FakeTasksRepository();
      final PatientTasksCubit c = cubit(repo);
      await c.load();
      final int before = repo.listCalls;
      await c.dismiss(task('1', TaskStatus.proposed));
      await c.complete(task('2', TaskStatus.open));
      expect(await c.add(title: 'Call family'), isTrue);
      expect(repo.dismissed, <String>['1']);
      expect(repo.completed, <String>['2']);
      expect(repo.added, <String>['Call family']);
      expect(repo.listCalls, before + 3);
      await c.close();
    });

    test('a blank title is not added', () async {
      final FakeTasksRepository repo = FakeTasksRepository();
      final PatientTasksCubit c = cubit(repo);
      expect(await c.add(title: '  '), isFalse);
      expect(repo.added, isEmpty);
      await c.close();
    });

    test('a failed action keeps the tasks and reports it', () async {
      final FakeTasksRepository repo = FakeTasksRepository()
        ..tasks = <PatientTask>[task('2', TaskStatus.open)]
        ..actionReply = Err<void>(apiFail('network_error'));
      final PatientTasksCubit c = cubit(repo);
      await c.load();
      await c.complete(task('2', TaskStatus.open));
      expect(c.state.actionError, isNotNull);
      expect(c.state.open, hasLength(1));
      expect(c.state.busyId, isNull);
      await c.close();
    });

    test('overdue is open, due and past, worked out from the clock', () {
      final DateTime past = now.subtract(const Duration(hours: 1));
      expect(task('1', TaskStatus.open, dueAt: past).isOverdue(now), isTrue);
      expect(task('1', TaskStatus.open).isOverdue(now), isFalse);
      expect(
        task('1', TaskStatus.completed, dueAt: past).isOverdue(now),
        isFalse,
      );
    });

    test(
      'the repository forces proposals to proposed and omits blanks',
      () async {
        final FakeAdapter a = FakeAdapter((RequestOptions o) {
          if (o.path.endsWith('/propose')) {
            return const FakeReply(200, <String, Object>{
              'tasks': <Object>[
                <String, Object>{
                  'id': 't1',
                  'title': 'Recheck',
                  'status': 'open',
                },
              ],
            });
          }
          return const FakeReply(200, <String, Object>{});
        });
        final TasksRepositoryImpl repo = TasksRepositoryImpl(await _client(a));
        final Result<List<PatientTask>> r = await repo.propose(
          'p1',
          idempotencyKey: 'k',
        );
        expect(
          (r as Ok<List<PatientTask>>).value.single.status,
          TaskStatus.proposed,
        );
        await repo.accept('t1');
        await repo.accept(
          't2',
          owner: ' Dr Rao ',
          dueAt: DateTime.utc(2026, 11, 13),
        );
        await repo.add('p1', title: ' Call ');
        expect(a.requests[1].path, '/tasks/t1/accept');
        expect(a.requests[1].data, <String, String>{});
        expect(a.requests[2].data, <String, String>{
          'owner': 'Dr Rao',
          'due_at': '2026-11-13T00:00:00.000Z',
        });
        expect(a.requests[3].data, <String, String>{'title': 'Call'});
      },
    );

    test(
      'team tasks read only patients with open tasks, open ones only',
      () async {
        final FakeCensusRepository census = FakeCensusRepository(
          <PatientSummary>[
            patientRow('a', openTasks: 2),
            patientRow('b'),
            patientRow('c', openTasks: 1),
          ],
        );
        final FakeTasksRepository repo = FakeTasksRepository()
          ..byPatient = <String, List<PatientTask>>{
            'a': <PatientTask>[
              task('1', TaskStatus.open, patientId: 'a'),
              task('2', TaskStatus.proposed, patientId: 'a'),
            ],
            'c': <PatientTask>[task('3', TaskStatus.open, patientId: 'c')],
          };
        final TeamTasksCubit c = TeamTasksCubit(census, repo);
        await c.load();
        expect(repo.listCalls, 2);
        expect(c.state.groups, hasLength(2));
        expect(c.state.openCount, 2);
        await c.close();
      },
    );

    test('one patient failing does not hide the others', () async {
      final FakeCensusRepository census = FakeCensusRepository(<PatientSummary>[
        patientRow('a', openTasks: 1),
        patientRow('c', openTasks: 1),
      ]);
      final FakeTasksRepository repo = FakeTasksRepository()
        ..failingPatients = <String>{'a'}
        ..byPatient = <String, List<PatientTask>>{
          'c': <PatientTask>[task('3', TaskStatus.open, patientId: 'c')],
        };
      final TeamTasksCubit c = TeamTasksCubit(census, repo);
      await c.load();
      expect(c.state.groups, hasLength(1));
      expect(c.state.failedPatients, 1);
      await c.close();
    });

    test('a failed census shows an error', () async {
      final FakeCensusRepository census = FakeCensusRepository(
        <PatientSummary>[],
      )..fails = true;
      final TeamTasksCubit c = TeamTasksCubit(census, FakeTasksRepository());
      await c.load();
      expect(c.state.error, isNotNull);
      await c.close();
    });

    test('team overdue counts only past open tasks', () async {
      final DateTime past = DateTime.now().subtract(const Duration(days: 1));
      final FakeCensusRepository census = FakeCensusRepository(<PatientSummary>[
        patientRow('a', openTasks: 2),
      ]);
      final FakeTasksRepository repo = FakeTasksRepository()
        ..byPatient = <String, List<PatientTask>>{
          'a': <PatientTask>[
            task('1', TaskStatus.open, patientId: 'a', dueAt: past),
            task('2', TaskStatus.open, patientId: 'a'),
          ],
        };
      final TeamTasksCubit c = TeamTasksCubit(census, repo);
      await c.load();
      expect(c.state.overdueCount(DateTime.now()), 1);
      await c.close();
    });

    test('completing from the team list reloads', () async {
      final FakeCensusRepository census = FakeCensusRepository(<PatientSummary>[
        patientRow('a', openTasks: 1),
      ]);
      final FakeTasksRepository repo = FakeTasksRepository()
        ..byPatient = <String, List<PatientTask>>{
          'a': <PatientTask>[task('1', TaskStatus.open, patientId: 'a')],
        };
      final TeamTasksCubit c = TeamTasksCubit(census, repo);
      await c.load();
      await c.complete(task('1', TaskStatus.open, patientId: 'a'));
      expect(repo.completed, <String>['1']);
      expect(repo.listCalls, 2);
      await c.close();
    });
  });

  group('sign-out', () {
    SignOutCubit cubit(FakeSignOutRepository repo, [FakeAiRepository? ai]) =>
        SignOutCubit(repo, ai ?? FakeAiRepository(), 'p1');

    test('with none typed the draft lists contingencies as missing', () async {
      final FakeSignOutRepository repo = FakeSignOutRepository();
      final SignOutCubit c = cubit(repo);
      await c.generate(const <Contingency>[]);
      expect(repo.sent.single, isEmpty);
      expect(
        c.state.content!.missingInformation,
        contains('contingency instructions'),
      );
      expect(c.state.aiState, AiState.draftReady);
      await c.close();
    });

    test('contingencies are sent as typed, as if/then', () async {
      final FakeSignOutRepository repo = FakeSignOutRepository();
      final SignOutCubit c = cubit(repo);
      await c.generate(const <Contingency>[
        Contingency(condition: 'SBP < 90', action: 'Call the senior'),
      ]);
      expect(repo.sent.single.single.toJson(), <String, String>{
        'if': 'SBP < 90',
        'then': 'Call the senior',
      });
      await c.close();
    });

    test(
      'the key stays for a retry and resets when the text changes',
      () async {
        final FakeSignOutRepository repo = FakeSignOutRepository()
          ..reply = Err<AiEnvelope>(apiFail('ai_unavailable', status: 503));
        final SignOutCubit c = cubit(repo);
        const List<Contingency> one = <Contingency>[
          Contingency(condition: 'a', action: 'b'),
        ];
        await c.generate(one);
        await c.generate(one);
        expect(repo.keys[1], repo.keys[0]);
        await c.generate(const <Contingency>[
          Contingency(condition: 'a', action: 'changed'),
        ]);
        expect(repo.keys[2], isNot(repo.keys[0]));
        await c.close();
      },
    );

    test('an outdated draft cannot be marked reviewed', () async {
      final FakeSignOutRepository repo = FakeSignOutRepository()
        ..reply = Ok<AiEnvelope>(signOutEnvelope(outdated: true));
      final FakeAiRepository ai = FakeAiRepository();
      final SignOutCubit c = cubit(repo, ai);
      await c.generate(const <Contingency>[]);
      expect(c.state.reviewBlockedReason, isNotNull);
      await c.markReviewed();
      expect(ai.reviewed_, isEmpty);
      await c.close();
    });

    test('mark reviewed sets the reviewed state', () async {
      final FakeAiRepository ai = FakeAiRepository();
      final SignOutCubit c = cubit(FakeSignOutRepository(), ai);
      await c.generate(const <Contingency>[]);
      await c.markReviewed();
      expect(ai.reviewed_, <String>['so1']);
      expect(c.state.isReviewed, isTrue);
      await c.close();
    });

    test('a refused review marks the sections the server named', () async {
      final FakeAiRepository ai = FakeAiRepository()
        ..reviewed = Err<AiEnvelope>(
          FakeAiRepository.failure(
            'review_blocked',
            status: 409,
            details: <String, dynamic>{
              'sections': <String>['plan'],
            },
          ),
        );
      final SignOutCubit c = cubit(FakeSignOutRepository(), ai);
      await c.generate(const <Contingency>[]);
      await c.markReviewed();
      expect(c.state.reviewError, isNotNull);
      expect(c.state.isReviewed, isFalse);
      await c.close();
    });

    test('the repository posts only the contingencies', () async {
      final FakeAdapter a = FakeAdapter(
        (RequestOptions o) => FakeReply(200, _envelopeBody(<String, Object>{})),
      );
      final SignOutRepositoryImpl repo = SignOutRepositoryImpl(
        await _client(a),
      );
      await repo.generate(
        'p1',
        contingencies: const <Contingency>[
          Contingency(condition: 'x', action: 'y'),
        ],
        idempotencyKey: 'k',
      );
      expect(a.requests.single.path, '/patients/p1/signout');
      expect(a.requests.single.data, <String, Object>{
        'contingencies': <Object>[
          <String, String>{'if': 'x', 'then': 'y'},
        ],
      });
    });
  });
}
