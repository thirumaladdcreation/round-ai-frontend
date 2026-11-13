import 'dart:async';

import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/census/models/census_intake.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';
import 'package:round_ai/features/evidence/models/evidence_result.dart';
import 'package:round_ai/features/evidence/repository/evidence_repository.dart';
import 'package:round_ai/features/learning/models/mcq_draft.dart';
import 'package:round_ai/features/learning/repository/teach_repository.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';
import 'package:round_ai/features/signout/models/contingency.dart';
import 'package:round_ai/features/signout/repository/signout_repository.dart';
import 'package:round_ai/features/tasks/models/patient_task.dart';
import 'package:round_ai/features/tasks/repository/tasks_repository.dart';

Failure apiFail(String code, {int? status}) => ApiFailure(
  ApiError(code: code, message: 'raw server text', status: status),
);

AiEnvelope envelope({
  String id = 'e1',
  String operation = 'x',
  String review = 'draft',
  bool outdated = false,
  Map<String, dynamic>? content,
}) {
  return AiEnvelope.fromJson(<String, dynamic>{
    'artifact_id': id,
    'operation': operation,
    'patient_id': 'p1',
    'context_revision': 3,
    'status': 'draft',
    'review_state': review,
    'outdated': outdated,
    'requires_review': review != 'reviewed',
    'created_at': '2026-11-12T09:00:00Z',
    'content': content ?? <String, dynamic>{},
  });
}

Map<String, dynamic> studyJson({String pmid = '111'}) => <String, dynamic>{
  'id': 's$pmid',
  'title': 'A trial of diuretics',
  'journal': 'NEJM',
  'study_type': 'RCT',
  'access_level': 'Abstract only',
  'publication_date': '2025-03-01',
  'pmid': pmid,
  'applicability': <String, dynamic>{
    'resembles': <String>['Age'],
    'differs': <String>['Renal function'],
    'unknown': <String>['Frailty'],
  },
};

EvidenceResult evidenceResult({
  List<Map<String, dynamic>> studies = const <Map<String, dynamic>>[],
  Map<String, dynamic>? retrieval,
}) {
  return EvidenceResult.fromEnvelope(
    envelope(
      operation: 'evidence_search',
      content: <String, dynamic>{
        'topic': 'Heart failure',
        'evidence': studies,
        'retrieval': ?retrieval,
      },
    ),
  );
}

class FakeEvidenceRepository implements EvidenceRepository {
  Result<EvidenceResult>? reply;
  Future<Result<EvidenceResult>> Function()? onSearch;
  final List<String> keys = <String>[];
  final List<String?> problems = <String?>[];
  final List<String?> topics = <String?>[];
  CancelToken? lastToken;

  @override
  Future<Result<EvidenceResult>> search(
    String patientId, {
    String? problemId,
    String? topic,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) {
    keys.add(idempotencyKey);
    problems.add(problemId);
    topics.add(topic);
    lastToken = cancelToken;
    final Future<Result<EvidenceResult>> Function()? handler = onSearch;
    if (handler != null) return handler();
    return Future<Result<EvidenceResult>>.value(
      reply ?? Ok<EvidenceResult>(evidenceResult(studies: [studyJson()])),
    );
  }
}

Map<String, dynamic> mcqJson({
  String id = 'q1',
  bool withKey = false,
  String status = 'unreviewed',
}) => <String, dynamic>{
  'id': id,
  'topic': 'Heart failure',
  'vignette': 'A 72-year-old with dyspnea.',
  'lead_in': 'What is the next best step?',
  'options': <String>['Alpha', 'Bravo', 'Charlie', 'Delta', 'Echo'],
  'difficulty': 'moderate',
  'review_status': status,
  if (withKey) 'correct_index': 2,
  if (withKey) 'explanation': 'Leaked explanation',
};

McqDraft mcqDraft({
  String id = 'q1',
  bool withKey = false,
  String status = 'unreviewed',
  String review = 'draft',
}) {
  return McqDraft.fromEnvelope(
    envelope(
      id: id,
      operation: 'generate_mcq',
      review: review,
      content: mcqJson(id: id, withKey: withKey, status: status),
    ),
  );
}

class FakeTeachRepository implements TeachRepository {
  Result<McqDraft>? generated;
  Future<Result<McqDraft>> Function()? onGenerate;
  Result<Map<String, dynamic>>? answered;
  Result<void> reported = const Ok<void>(null);
  Result<List<McqDraft>>? queue;

  final List<String> keys = <String>[];
  final List<String> problemIds = <String>[];
  final List<int> answers = <int>[];
  final List<String> reports = <String>[];
  int answerCalls = 0;

  @override
  Future<Result<McqDraft>> generate(
    String patientId, {
    required String problemId,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) {
    keys.add(idempotencyKey);
    problemIds.add(problemId);
    final Future<Result<McqDraft>> Function()? handler = onGenerate;
    if (handler != null) return handler();
    return Future<Result<McqDraft>>.value(
      generated ?? Ok<McqDraft>(mcqDraft()),
    );
  }

  @override
  Future<Result<Map<String, dynamic>>> answer(
    String questionId, {
    required int selectedIndex,
  }) async {
    answerCalls++;
    answers.add(selectedIndex);
    return answered ??
        const Ok<Map<String, dynamic>>(<String, dynamic>{
          'correct_index': 2,
          'explanation': 'Charlie is keyed because of volume overload.',
          'option_explanations': <String>[
            'Alpha is wrong.',
            'Bravo is wrong.',
            'Delta is wrong.',
            'Echo is wrong.',
          ],
          'references': <String>['PMID 123'],
        });
  }

  @override
  Future<Result<void>> report(
    String questionId, {
    required String reason,
  }) async {
    reports.add(reason);
    return reported;
  }

  @override
  Future<Result<List<McqDraft>>> questions(String patientId) async {
    return queue ?? Ok<List<McqDraft>>(<McqDraft>[mcqDraft(withKey: true)]);
  }
}

PatientTask task(
  String id,
  TaskStatus status, {
  String patientId = 'p1',
  String? owner,
  DateTime? dueAt,
}) => PatientTask(
  id: id,
  patientId: patientId,
  title: 'Task $id',
  status: status,
  owner: owner,
  dueAt: dueAt,
);

class FakeTasksRepository implements TasksRepository {
  List<PatientTask> tasks = <PatientTask>[];
  Map<String, List<PatientTask>> byPatient = <String, List<PatientTask>>{};
  Set<String> failingPatients = <String>{};
  Result<List<PatientTask>>? proposeReply;
  Future<Result<List<PatientTask>>> Function()? onPropose;
  Result<void> actionReply = const Ok<void>(null);
  Result<List<PatientTask>>? listReply;

  final List<String> proposeKeys = <String>[];
  final List<String> accepted = <String>[];
  final List<(String?, DateTime?)> acceptDetails = <(String?, DateTime?)>[];
  final List<String> dismissed = <String>[];
  final List<String> completed = <String>[];
  final List<String> added = <String>[];
  int listCalls = 0;
  int proposeCalls = 0;

  @override
  Future<Result<List<PatientTask>>> list(String patientId) async {
    listCalls++;
    if (failingPatients.contains(patientId)) {
      return Err<List<PatientTask>>(apiFail('network_error'));
    }
    return listReply ??
        Ok<List<PatientTask>>(byPatient[patientId] ?? List.of(tasks));
  }

  @override
  Future<Result<List<PatientTask>>> propose(
    String patientId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) {
    proposeCalls++;
    proposeKeys.add(idempotencyKey);
    final Future<Result<List<PatientTask>>> Function()? handler = onPropose;
    if (handler != null) return handler();
    return Future<Result<List<PatientTask>>>.value(
      proposeReply ?? const Ok<List<PatientTask>>(<PatientTask>[]),
    );
  }

  @override
  Future<Result<void>> add(
    String patientId, {
    required String title,
    String? owner,
    DateTime? dueAt,
  }) async {
    added.add(title);
    return actionReply;
  }

  @override
  Future<Result<void>> accept(
    String taskId, {
    String? owner,
    DateTime? dueAt,
  }) async {
    accepted.add(taskId);
    acceptDetails.add((owner, dueAt));
    return actionReply;
  }

  @override
  Future<Result<void>> dismiss(String taskId) async {
    dismissed.add(taskId);
    return actionReply;
  }

  @override
  Future<Result<void>> complete(String taskId) async {
    completed.add(taskId);
    return actionReply;
  }
}

class FakeSignOutRepository implements SignOutRepository {
  Result<AiEnvelope>? reply;
  Future<Result<AiEnvelope>> Function()? onGenerate;
  final List<String> keys = <String>[];
  final List<List<Contingency>> sent = <List<Contingency>>[];

  @override
  Future<Result<AiEnvelope>> generate(
    String patientId, {
    required List<Contingency> contingencies,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) {
    keys.add(idempotencyKey);
    sent.add(contingencies);
    final Future<Result<AiEnvelope>> Function()? handler = onGenerate;
    if (handler != null) return handler();
    return Future<Result<AiEnvelope>>.value(
      reply ?? Ok<AiEnvelope>(signOutEnvelope()),
    );
  }
}

AiEnvelope signOutEnvelope({
  String id = 'so1',
  bool outdated = false,
  List<Object>? missing,
}) {
  return envelope(
    id: id,
    operation: 'signout',
    outdated: outdated,
    content: <String, dynamic>{
      'one_liner': <String, Object>{
        'text': '72F with CHF.',
        'label': 'From chart',
      },
      'sections': <Object>[],
      'missing_information': missing ?? <Object>['contingency instructions'],
      'conflicts': <Object>[],
      'validation_issues': <Object>[],
    },
  );
}

PatientSummary patientRow(String id, {int openTasks = 0}) => PatientSummary(
  id: id,
  teamId: 't1',
  displayName: 'Patient $id',
  room: '50$id',
  ageBand: '70s',
  sex: 'F',
  summaryState: SummaryState.notGenerated,
  unreviewedFacts: 0,
  openTasks: openTasks,
);

class FakeCensusRepository implements CensusRepository {
  FakeCensusRepository(this.patients);

  List<PatientSummary> patients;
  bool fails = false;

  @override
  Future<Result<List<PatientSummary>>> loadPatients() async {
    if (fails) return Err<List<PatientSummary>>(apiFail('network_error'));
    return Ok<List<PatientSummary>>(patients);
  }

  @override
  Future<Result<PatientSummary>> addPatient(NewPatient patient) async =>
      Ok<PatientSummary>(patients.first);

  @override
  Future<Result<CensusIntakeProposal>> intakeCensus({
    required TempMedia media,
    required String idempotencyKey,
    String? teamId,
    CancelToken? cancelToken,
  }) async =>
      Err<CensusIntakeProposal>(apiFail('ai_disabled', status: 503));

  @override
  Future<Result<CensusConfirmResult>> confirmCensus(
    String intakeId, {
    required List<ProposedCensusPatient> items,
  }) async =>
      Err<CensusConfirmResult>(apiFail('ai_disabled', status: 503));

  @override
  Future<Result<CensusExport>> exportCensus({String? teamId}) async =>
      Ok<CensusExport>(
        CensusExport(text: patients.map((PatientSummary p) => p.displayName).join('\n')),
      );

  @override
  Future<Result<void>> setSortOrder(String patientId, int sortOrder) async =>
      const Ok<void>(null);
}

class FakePatientRepository implements PatientRepository {
  FakePatientRepository({this.plan = const <String>[]});

  List<String> plan;
  bool fails = false;

  @override
  Future<Result<PatientDetail>> loadDetail(String patientId) async {
    if (fails) return Err<PatientDetail>(apiFail('network_error'));
    return Ok<PatientDetail>(
      PatientDetail(
        patient: patientRow(patientId),
        revision: 1,
        planToday: plan,
      ),
    );
  }

  @override
  Future<Result<PatientChanges>> loadChanges(String patientId) async =>
      const Ok<PatientChanges>(
        PatientChanges(hasBaseline: false, items: <InsightItem>[]),
      );

  @override
  Future<Result<void>> savePlan(String patientId, List<String> lines) async {
    plan = lines;
    return const Ok<void>(null);
  }
}
