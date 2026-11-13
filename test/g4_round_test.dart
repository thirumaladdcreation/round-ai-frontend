import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/rounds/models/prepare_result.dart';
import 'package:round_ai/features/rounds/models/presentation_draft.dart';
import 'package:round_ai/features/rounds/models/round_brief.dart';
import 'package:round_ai/features/rounds/models/round_reminder.dart';
import 'package:round_ai/features/rounds/repository/demo_round_repository.dart';
import 'package:round_ai/features/rounds/repository/round_repository.dart';
import 'package:round_ai/features/rounds/repository/round_repository_impl.dart';
import 'package:round_ai/features/rounds/widgets/prepare_sheet.dart';
import 'package:round_ai/features/rounds/widgets/reminder_section.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/widgets/home_morning_brief.dart';

import 'support/fake_adapter.dart';

Future<ApiClient> _client(FakeAdapter adapter) async {
  final SessionStore session = SessionStore(MemoryTokenStore());
  await session.save('tok', persist: false);
  return ApiClient(session: session, dio: fakeDio(adapter));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoundBriefCounts', () {
    test('empty brief has quiet headline', () {
      const RoundBriefCounts c = RoundBriefCounts();
      expect(c.isQuiet, isTrue);
      expect(c.headline, 'No unreviewed facts or outdated summaries.');
      expect(c.lines, isEmpty);
    });

    test('renders deterministic count lines without urgency', () {
      const RoundBriefCounts c = RoundBriefCounts(
        unreviewedFacts: 2,
        outdatedSummaries: 3,
        overdueTasks: 1,
      );
      expect(c.headline, '2 chart facts are waiting for review');
      expect(c.lines, <String>[
        '2 chart facts are waiting for review',
        '3 summaries are outdated',
        '1 task is overdue',
      ]);
      expect(c.lines.join(' '), isNot(contains('urgent')));
      expect(c.lines.join(' '), isNot(contains('reassessment')));
    });
  });

  group('RoundBrief parsing', () {
    test('parses patients and derives overdue from tasks', () {
      final RoundBrief brief = RoundBrief.fromJson(<String, dynamic>{
        'date': '2026-11-13',
        'assembled_in_code': true,
        'ordering': 'sort_order_then_room',
        'counts': <String, int>{
          'patients': 1,
          'unreviewed_facts': 4,
          'outdated_summaries': 1,
        },
        'patients': <Object>[
          <String, Object>{
            'patient_id': 'p1',
            'display_name': 'Ada',
            'room': '12',
            'sort_order': 1,
            'summary_state': 'Outdated',
            'unreviewed_facts': 4,
            'what_changed': <String, Object>{
              'status': 'ok',
              'computed_in_code': true,
              'nothing_new': false,
              'new_facts': <Object>[
                <String, String>{'label': 'Cr', 'value': '2.1'},
              ],
            },
            'trends': <Object>[],
            'conflicts': <Object>[],
            'pending_items': <Object>[],
            'tasks': <Object>[
              <String, Object>{
                'id': 't1',
                'text': 'Check labs',
                'overdue': true,
                'due_today': false,
              },
              <String, Object>{
                'id': 't2',
                'text': 'Call RN',
                'overdue': false,
                'due_today': true,
              },
            ],
            'reminders': <Object>[],
            'yesterday_comparisons': <Object>[],
            'missing_information': <String>['Echo'],
            'plan_today': <String, String>{'text': 'Diurese'},
            'problems': <Object>[
              <String, String>{
                'id': 'pr1',
                'label': 'AKI',
                'state': 'confirmed',
              },
            ],
          },
        ],
      });
      expect(brief.counts.unreviewedFacts, 4);
      expect(brief.counts.outdatedSummaries, 1);
      expect(brief.counts.overdueTasks, 1);
      expect(brief.patients.single.whatChanged.computedInCode, isTrue);
      expect(brief.patients.single.planToday, 'Diurese');
    });
  });

  group('RoundRepositoryImpl', () {
    test('loadBrief GETs /round/brief', () async {
      final FakeAdapter a = FakeAdapter((RequestOptions o) {
        expect(o.method, 'GET');
        expect(o.path, '/round/brief');
        return FakeReply(200, <String, Object>{
          'date': '2026-11-13',
          'counts': <String, int>{
            'patients': 0,
            'unreviewed_facts': 0,
            'outdated_summaries': 0,
          },
          'patients': <Object>[],
        });
      });
      final RoundRepositoryImpl repo = RoundRepositoryImpl(await _client(a));
      final Result<RoundBrief> r = await repo.loadBrief();
      expect(r, isA<Ok<RoundBrief>>());
      expect((r as Ok<RoundBrief>).value.counts.isQuiet, isTrue);
    });

    test('preparePresentations returns partial failures', () async {
      final FakeAdapter a = FakeAdapter((RequestOptions o) {
        expect(o.method, 'POST');
        expect(o.path, '/round/brief/prepare');
        expect(o.headers['Idempotency-Key'], isNotEmpty);
        return FakeReply(200, <String, Object>{
          'date': '2026-11-13',
          'requested': 2,
          'generated': 1,
          'failed': 1,
          'daily_cap': 50,
          'calls_remaining_before': 2,
          'results': <Object>[
            <String, Object>{
              'patient_id': 'p1',
              'ok': true,
              'artifact_id': 'a1',
              'word_count': 180,
              'requires_review': true,
            },
            <String, Object>{
              'patient_id': 'p2',
              'ok': false,
              'error': <String, String>{
                'code': 'daily_limit',
                'message': 'Daily AI usage limit reached.',
              },
            },
          ],
        });
      });
      final RoundRepositoryImpl repo = RoundRepositoryImpl(await _client(a));
      final Result<PreparePresentationsResult> r = await repo
          .preparePresentations(
            patientIds: <String>['p1', 'p2'],
            idempotencyKey: IdempotencyKey.create(),
          );
      final PreparePresentationsResult value =
          (r as Ok<PreparePresentationsResult>).value;
      expect(value.generated, 1);
      expect(value.failed, 1);
      expect(value.hasFailures, isTrue);
      expect(value.results.last.isDailyLimit, isTrue);
      expect(
        value.results.last.failureReason,
        contains('Daily AI usage limit'),
      );
    });

    test('ackReminder posts checked state', () async {
      final FakeAdapter a = FakeAdapter((RequestOptions o) {
        expect(o.path, '/patients/p1/reminders/r1/ack');
        expect(o.data, containsPair('state', 'checked'));
        return FakeReply(200, <String, Object>{
          'patient_id': 'p1',
          'rule_id': 'r1',
          'day': '2026-11-13',
          'state': 'checked',
          'frame': reminderFrame,
        });
      });
      final RoundRepositoryImpl repo = RoundRepositoryImpl(await _client(a));
      final Result<ReminderAck> r = await repo.ackReminder(
        'p1',
        'r1',
        state: ReminderAckState.checked,
      );
      expect((r as Ok<ReminderAck>).value.state, ReminderAckState.checked);
    });

    test('present parses spoken text and word count', () async {
      final FakeAdapter a = FakeAdapter((RequestOptions o) {
        expect(o.path, '/patients/p1/present');
        return FakeReply(200, <String, Object>{
          'artifact_id': 'art1',
          'operation': 'present_patient',
          'patient_id': 'p1',
          'context_revision': 1,
          'status': 'draft',
          'review_state': 'draft',
          'outdated': false,
          'requires_review': true,
          'created_at': '2026-11-13T00:00:00Z',
          'content': <String, Object>{
            'sentences': <Object>[
              <String, Object>{
                'text': 'Creatinine rose to 2.1.',
                'label': 'From chart',
                'fact_ids': <String>['f1'],
              },
            ],
            'plan_sentences': <Object>[],
            'spoken_text': 'Creatinine rose to 2.1.',
            'word_count': 4,
            'word_budget': <String, int>{'min': 150, 'max': 220},
            'estimated_seconds': 2,
            'label': presentationReviewLabel,
            'missing_information': <String>[],
          },
        });
      });
      final RoundRepositoryImpl repo = RoundRepositoryImpl(await _client(a));
      final Result<PresentationResult> r = await repo.present(
        'p1',
        idempotencyKey: 'k1',
      );
      final PresentationResult value = (r as Ok<PresentationResult>).value;
      expect(value.draft.spokenText, 'Creatinine rose to 2.1.');
      expect(value.draft.sentences.single.factIds, <String>['f1']);
      expect(value.requiresReview, isTrue);
    });
  });

  group('reminder ack UI', () {
    testWidgets('acks checked and shows recorded state', (
      WidgetTester tester,
    ) async {
      final _FakeRound repo = _FakeRound();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReminderSection(
              patientId: 'p1',
              repository: repo,
              reminders: const <RoundReminder>[
                RoundReminder(
                  ruleId: 'r1',
                  name: 'AKI volume',
                  prompts: <ReminderPrompt>[
                    ReminderPrompt(text: 'Review intake/output'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text(reminderFrame.toUpperCase()), findsOneWidget);
      await tester.tap(find.text('Checked'));
      await tester.pumpAndSettle();
      expect(repo.acks, 1);
      expect(find.text('Recorded · Checked'), findsOneWidget);
    });

    testWidgets('empty reminders show friendly message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReminderSection(
              patientId: 'p1',
              reminders: <RoundReminder>[],
            ),
          ),
        ),
      );
      expect(find.text(remindersEmptyMessage), findsOneWidget);
    });
  });

  group('prepare sheet', () {
    testWidgets('lists partial failure reasons', (WidgetTester tester) async {
      final _FakeRound repo = _FakeRound()
        ..prepareReply = Ok<PreparePresentationsResult>(
          PreparePresentationsResult(
            date: '2026-11-13',
            requested: 2,
            generated: 1,
            failed: 1,
            results: const <PreparePatientResult>[
              PreparePatientResult(
                patientId: 'p1',
                ok: true,
                wordCount: 160,
              ),
              PreparePatientResult(
                patientId: 'p2',
                ok: false,
                errorCode: 'daily_limit',
                errorMessage: 'Daily AI usage limit reached.',
              ),
            ],
          ),
        );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreparePresentationsSheet(
              repository: repo,
              patients: const <RoundPatientCard>[
                RoundPatientCard(patientId: 'p1', displayName: 'Ada'),
                RoundPatientCard(patientId: 'p2', displayName: 'Ben'),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Prepare selected'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Generated 1 of 2'), findsOneWidget);
      expect(find.textContaining('Daily AI usage limit'), findsOneWidget);
      expect(find.textContaining('Ada'), findsWidgets);
    });
  });

  group('morning brief widget', () {
    testWidgets('shows count wording not urgency', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeMorningBrief(
              snapshot: HomeSnapshot(
                clinicianName: 'Dr Test',
                greeting: 'Good morning',
                dateLabel: 'Fri',
                patientCount: 2,
                pendingTaskCount: 0,
                draftsAwaitingReview: 0,
                roundsStatus: 'ready',
                latestChartStamp: '',
                patients: const <HomePatientPreview>[
                  HomePatientPreview(
                    id: 'p1',
                    name: 'Ada',
                    room: '1',
                    reason: 'AKI',
                    latestUpdate: '',
                    pendingTasks: 0,
                  ),
                ],
                attention: const <HomeAttentionItem>[],
                isSynthetic: false,
                hasPartialChart: false,
                briefCounts: const RoundBriefCounts(
                  patients: 2,
                  outdatedSummaries: 3,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('3 summaries are outdated'), findsOneWidget);
      expect(find.textContaining('early reassessment'), findsNothing);
    });
  });

  test('demo repository returns brief patients', () async {
    final DemoRoundRepository demo = DemoRoundRepository();
    final Result<RoundBrief> r = await demo.loadBrief();
    expect((r as Ok<RoundBrief>).value.patients, isNotEmpty);
  });
}

class _FakeRound implements RoundRepository {
  int acks = 0;
  Result<PreparePresentationsResult>? prepareReply;

  @override
  Future<Result<ReminderAck>> ackReminder(
    String patientId,
    String ruleId, {
    required ReminderAckState state,
    String? note,
    String? date,
  }) async {
    acks++;
    return Ok<ReminderAck>(ReminderAck(state: state, note: note));
  }

  @override
  Future<Result<RoundBrief>> loadBrief({String? date, String? teamId}) async =>
      Err<RoundBrief>(const UnknownFailure('unused'));

  @override
  Future<Result<ReminderListResult>> loadReminders(
    String patientId, {
    String? date,
  }) async =>
      Err<ReminderListResult>(const UnknownFailure('unused'));

  @override
  Future<Result<PreparePresentationsResult>> preparePresentations({
    required List<String> patientIds,
    required String idempotencyKey,
    String? date,
    CancelToken? cancelToken,
  }) async =>
      prepareReply ?? Err<PreparePresentationsResult>(const UnknownFailure('x'));

  @override
  Future<Result<PresentationResult>> present(
    String patientId, {
    required String idempotencyKey,
    String? date,
    CancelToken? cancelToken,
  }) async =>
      Err<PresentationResult>(const UnknownFailure('unused'));
}
