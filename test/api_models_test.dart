import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/authentication/models/app_user.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/learning/models/mcq.dart';
import 'package:round_ai/features/patient/models/evidence_card.dart';
import 'package:round_ai/features/patient/models/fact.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/tasks/models/patient_task.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';

Map<String, dynamic> _envelope({
  String status = 'draft',
  String review = 'draft',
  bool outdated = false,
  Map<String, dynamic>? content,
}) {
  return <String, dynamic>{
    'artifact_id': 'a1',
    'operation': 'summarize_patient',
    'patient_id': 'p1',
    'context_revision': 17,
    'status': status,
    'review_state': review,
    'outdated': outdated,
    'requires_review': true,
    'provider': 'openai',
    'model': 'm1',
    'prompt_version': 'v3',
    'generation_ms': 4200,
    'created_at': '2026-11-12T09:00:00Z',
    'content': content ?? <String, dynamic>{},
  };
}

void main() {
  group('AiEnvelope and state mapping', () {
    test('parses every envelope field', () {
      final AiEnvelope e = AiEnvelope.fromJson(_envelope());
      expect(e.artifactId, 'a1');
      expect(e.contextRevision, 17);
      expect(e.status, AiStatus.draft);
      expect(e.requiresReview, isTrue);
      expect(e.generationMs, 4200);
      expect(e.createdAt, DateTime.utc(2026, 11, 12, 9));
    });

    test('maps to the state chip', () {
      AiState of(Map<String, dynamic> json) =>
          AiState.fromEnvelope(AiEnvelope.fromJson(json));
      expect(AiState.fromEnvelope(null), AiState.notGenerated);
      expect(of(_envelope()), AiState.draftReady);
      expect(of(_envelope(status: 'partial')), AiState.partial);
      expect(of(_envelope(review: 'reviewed')), AiState.reviewed);
      expect(of(_envelope(outdated: true)), AiState.outdated);
      // Outdated wins over reviewed: the review applied to an old version.
      expect(
        of(_envelope(review: 'reviewed', outdated: true)),
        AiState.outdated,
      );
    });

    test('counts validation issues for a partial result', () {
      final AiEnvelope e = AiEnvelope.fromJson(
        _envelope(
          status: 'partial',
          content: <String, dynamic>{
            'validation_issues': <Object>[
              <String, Object>{
                'code': 'unsupported',
                'section': 'plan',
                'message': 'x',
              },
              'a plain string issue',
            ],
          },
        ),
      );
      expect(e.validationIssues.length, 2);
      expect(e.validationIssues.first.section, 'plan');
    });

    test('a missing requires_review still means review is required', () {
      final Map<String, dynamic> json = _envelope()..remove('requires_review');
      expect(AiEnvelope.fromJson(json).requiresReview, isTrue);
    });
  });

  test('a claim keeps its fact ids and label', () {
    final Claim chart = Claim.fromJson(<String, dynamic>{
      'text': 'Creatinine rose.',
      'fact_ids': <String>['f1', 'f2'],
      'label': 'From chart',
    });
    expect(chart.label, ClaimLabel.fromChart);
    expect(chart.factIds, <String>['f1', 'f2']);
    final Claim ai = Claim.fromJson(<String, dynamic>{'text': 'Maybe.'});
    expect(ai.label, ClaimLabel.aiInterpretation);
  });

  test('patients parse the census fields and states', () {
    final PatientSummary p = PatientSummary.fromJson(<String, dynamic>{
      'id': 'p1',
      'team_id': 't1',
      'display_name': 'Fictional Patient',
      'room': '509A',
      'age_band': '70-79',
      'sex': 'F',
      'summary_state': 'Draft ready',
      'unreviewed_facts': 3,
      'open_tasks': 2,
    });
    expect(p.summaryState, SummaryState.draftReady);
    expect(p.unreviewedFacts, 3);
    expect(SummaryState.parse('Not generated'), SummaryState.notGenerated);
    expect(SummaryState.parse('Outdated'), SummaryState.outdated);
    expect(SummaryState.parse(null), SummaryState.notGenerated);
  });

  test('patient display names drop trailing (fictional) seed marker', () {
    final PatientSummary p = PatientSummary.fromJson(<String, dynamic>{
      'id': 'p1',
      'team_id': 't1',
      'display_name': 'Rosa Martinez (fictional)',
      'room': '509A',
      'age_band': '60s',
      'sex': 'F',
      'summary_state': 'Not generated',
      'unreviewed_facts': 0,
      'open_tasks': 0,
    });
    expect(p.displayName, 'Rosa Martinez');
  });

  test('a fact with no time keeps the time unknown', () {
    final Fact f = Fact.fromJson(<String, dynamic>{
      'id': 'f1',
      'name': 'Creatinine',
      'value': '1.7',
      'unit': 'mg/dL',
      'status': 'pending',
    });
    expect(f.eventTime, isNull);
    expect(f.status, FactStatus.pending);
  });

  test('an unknown problem state is a suggestion, never confirmed', () {
    expect(ProblemState.parse('something_new'), ProblemState.suggested);
    expect(ProblemState.parse('confirmed'), ProblemState.confirmed);
  });

  test('a task with no owner or due date stays blank', () {
    final PatientTask t = PatientTask.fromJson(<String, dynamic>{
      'id': 't1',
      'patient_id': 'p1',
      'title': 'Repeat BMP',
      'status': 'proposed',
    });
    expect(t.owner, isNull);
    expect(t.dueAt, isNull);
    expect(t.status, TaskStatus.proposed);
  });

  test('an MCQ has no answer key until it is submitted', () {
    final Mcq q = Mcq.fromJson(<String, dynamic>{
      'id': 'q1',
      'topic': 'Cardiorenal',
      'vignette': 'v',
      'lead_in': 'Which?',
      'options': <String>['a', 'b', 'c', 'd', 'e'],
      'difficulty': 'Basic',
    });
    expect(q.options.length, 5);
    expect(q.correctIndex, isNull);
    expect(q.isReviewed, isFalse);
  });

  test('an evidence card only builds a PubMed link from a PMID', () {
    final EvidenceCard none = EvidenceCard.fromJson(<String, dynamic>{
      'id': 'e1',
      'title': 'T',
    });
    expect(none.pubmedUri, isNull);
    expect(none.accessLevel, 'Source not available');

    final EvidenceCard card = EvidenceCard.fromJson(<String, dynamic>{
      'id': 'e2',
      'title': 'T',
      'pmid': '123',
      'access_level': 'Abstract only',
      'applicability': <String, Object>{
        'resembles': <String>['age'],
        'unknown': <String>['eGFR'],
      },
    });
    expect(card.pubmedUri.toString(), 'https://pubmed.ncbi.nlm.nih.gov/123/');
    expect(card.applicability.unknown, <String>['eGFR']);
  });

  test('/me gives the user, teams, and the AI switch', () {
    final MeProfile me = MeProfile.fromJson(<String, dynamic>{
      'user': <String, Object>{'id': 'u1', 'name': 'Dr. T', 'role': 'resident'},
      'teams': <Object>[
        <String, Object>{'id': 't1', 'name': 'A', 'patient_count': 4},
      ],
      'ai_enabled': false,
    });
    expect(me.user.name, 'Dr. T');
    expect(me.teams.single.patientCount, 4);
    expect(me.aiEnabled, isFalse);
    expect(
      MeProfile.fromJson(<String, dynamic>{
        'user': <String, Object>{},
      }).aiEnabled,
      isFalse,
    );
  });
}
