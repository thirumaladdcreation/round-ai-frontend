import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/census/data/demo_patients.dart';
import 'package:round_ai/features/patient/data/patient_workspace.dart';
import 'package:round_ai/features/rounds/models/prepare_result.dart';
import 'package:round_ai/features/rounds/models/presentation_draft.dart';
import 'package:round_ai/features/rounds/models/round_brief.dart';
import 'package:round_ai/features/rounds/models/round_reminder.dart';
import 'package:round_ai/features/rounds/repository/round_repository.dart';

/// Demo brief/presentation/reminders for `USE_DEMO=true`.
class DemoRoundRepository implements RoundRepository {
  DemoRoundRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, ReminderAckState> _acks = <String, ReminderAckState>{};
  int _artifactSeq = 0;

  String _day() {
    final DateTime n = _clock();
    final String m = n.month.toString().padLeft(2, '0');
    final String d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  @override
  Future<Result<RoundBrief>> loadBrief({String? date, String? teamId}) async {
    final String day = date ?? _day();
    final List<RoundPatientCard> cards = <RoundPatientCard>[];
    int unreviewed = 0;
    int outdated = 0;
    int overdue = 0;
    for (int i = 0; i < demoPatients.length; i++) {
      final CensusPatient p = demoPatients[i];
      final PatientWorkspace? ws = workspaceFor(p.id);
      final bool pending = p.status == PatientStatus.reviewPending;
      if (pending) unreviewed += 1;
      final List<RoundTaskItem> tasks = (ws?.tasks ?? const <ChartTask>[])
          .map(
            (ChartTask t) => RoundTaskItem(
              id: t.id,
              text: t.title,
              due: t.due,
              dueToday: t.dueNow,
              overdue: t.dueNow,
            ),
          )
          .toList();
      overdue += tasks.where((RoundTaskItem t) => t.overdue).length;
      cards.add(
        RoundPatientCard(
          patientId: p.id,
          displayName: p.name,
          room: p.room,
          sortOrder: i + 1,
          summaryState: pending ? 'Draft ready' : 'Reviewed',
          unreviewedFacts: pending ? 1 : 0,
          whatChanged: RoundChangedBlock(
            status: 'ok',
            nothingNew: ws == null || ws.changes.isEmpty,
            message: ws == null || ws.changes.isEmpty
                ? 'Nothing new since the last reviewed summary.'
                : null,
            newFacts: ws == null
                ? const <Map<String, dynamic>>[]
                : ws.changes
                      .map(
                        (String c) => <String, dynamic>{
                          'label': c,
                          'value': '',
                        },
                      )
                      .toList(),
          ),
          pendingItems: const <RoundPendingItem>[],
          tasks: tasks,
          reminders: _demoReminders(p.id),
          missingInformation: ws?.missing ?? const <String>[],
          planToday: null,
          problems: <RoundProblemItem>[
            RoundProblemItem(
              id: 'demo-${p.id}',
              label: p.problem,
              state: 'confirmed',
            ),
          ],
        ),
      );
    }
    return Ok<RoundBrief>(
      RoundBrief(
        date: day,
        counts: RoundBriefCounts(
          patients: cards.length,
          unreviewedFacts: unreviewed,
          outdatedSummaries: outdated,
          overdueTasks: overdue,
        ),
        patients: cards,
        note:
            'Day brief assembled in code from the chart. No AI ranking or urgency.',
      ),
    );
  }

  List<RoundReminder> _demoReminders(String patientId) {
    // Demo has no approved rule library; keep empty so the empty state shows.
    if (patientId.isEmpty) return const <RoundReminder>[];
    return const <RoundReminder>[];
  }

  @override
  Future<Result<PreparePresentationsResult>> preparePresentations({
    required List<String> patientIds,
    required String idempotencyKey,
    String? date,
    CancelToken? cancelToken,
  }) async {
    final List<PreparePatientResult> results = <PreparePatientResult>[];
    for (final String id in patientIds) {
      final CensusPatient? p = patientById(id);
      if (p == null) {
        results.add(
          PreparePatientResult(
            patientId: id,
            ok: false,
            errorCode: 'not_found',
            errorMessage: 'Patient not found',
          ),
        );
        continue;
      }
      final PatientWorkspace? ws = workspaceFor(id);
      if (ws == null) {
        results.add(
          PreparePatientResult(
            patientId: id,
            ok: false,
            errorCode: 'no_reviewed_facts',
            errorMessage: 'Review chart facts first.',
          ),
        );
        continue;
      }
      _artifactSeq += 1;
      final List<String> words = ws.oralDraft.split(RegExp(r'\s+'));
      results.add(
        PreparePatientResult(
          patientId: id,
          ok: true,
          artifactId: 'demo-present-$_artifactSeq',
          status: 'draft',
          wordCount: words.where((String w) => w.isNotEmpty).length,
          requiresReview: true,
        ),
      );
    }
    final int ok = results.where((PreparePatientResult r) => r.ok).length;
    return Ok<PreparePresentationsResult>(
      PreparePresentationsResult(
        date: date ?? _day(),
        requested: patientIds.length,
        generated: ok,
        failed: patientIds.length - ok,
        dailyCap: 100,
        callsRemainingBefore: 100,
        results: results,
        note: 'Partial results are returned explicitly.',
      ),
    );
  }

  @override
  Future<Result<PresentationResult>> present(
    String patientId, {
    required String idempotencyKey,
    String? date,
    CancelToken? cancelToken,
  }) async {
    final PatientWorkspace? ws = workspaceFor(patientId);
    if (ws == null) {
      return Err<PresentationResult>(
        ApiFailure(
          const ApiError(
            code: 'no_reviewed_facts',
            message: 'Review chart facts first.',
          ),
        ),
      );
    }
    _artifactSeq += 1;
    final List<String> parts = ws.oralDraft
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((String s) => s.trim().isNotEmpty)
        .toList();
    final List<Claim> sentences = parts
        .map(
          (String t) => Claim(
            text: t.trim(),
            label: ClaimLabel.fromChart,
            factIds: const <String>['demo-fact'],
          ),
        )
        .toList();
    final String spoken = sentences.map((Claim c) => c.text).join(' ');
    final int words = spoken
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .length;
    final AiEnvelope envelope = AiEnvelope(
      artifactId: 'demo-present-$_artifactSeq',
      operation: 'present_patient',
      patientId: patientId,
      contextRevision: 1,
      status: AiStatus.draft,
      reviewState: ReviewState.draft,
      outdated: false,
      requiresReview: true,
      provider: 'demo',
      model: 'demo',
      promptVersion: '1',
      generationMs: 0,
      createdAt: _clock(),
      content: <String, dynamic>{
        'sentences': sentences
            .map(
              (Claim c) => <String, dynamic>{
                'text': c.text,
                'label': 'From chart',
                'fact_ids': c.factIds,
              },
            )
            .toList(),
        'plan_sentences': <Object>[],
        'spoken_text': spoken,
        'word_count': words,
        'word_budget': <String, int>{
          'min': presentationWordMin,
          'max': presentationWordMax,
        },
        'estimated_seconds': ((words / 180) * 60).round(),
        'target_duration': '60-90 seconds',
        'flags': <Object>[],
        'missing_information': ws.missing,
        'label': presentationReviewLabel,
        'requires_review': true,
      },
    );
    return Ok<PresentationResult>(PresentationResult.fromEnvelope(envelope));
  }

  @override
  Future<Result<ReminderListResult>> loadReminders(
    String patientId, {
    String? date,
  }) async {
    return Ok<ReminderListResult>(
      ReminderListResult(
        date: date ?? _day(),
        reminders: _demoReminders(patientId),
        note: remindersEmptyMessage,
      ),
    );
  }

  @override
  Future<Result<ReminderAck>> ackReminder(
    String patientId,
    String ruleId, {
    required ReminderAckState state,
    String? note,
    String? date,
  }) async {
    _acks['$patientId:$ruleId'] = state;
    return Ok<ReminderAck>(ReminderAck(state: state, note: note));
  }
}
