import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/learning/models/mcq_draft.dart';
import 'package:round_ai/features/learning/repository/teach_repository.dart';

class TeachRepositoryImpl implements TeachRepository {
  TeachRepositoryImpl(this._client);

  final ApiClient _client;

  /// The operation name of a saved question, for the review queue.
  static const String operation = 'generate_mcq';

  @override
  Future<Result<McqDraft>> generate(
    String patientId, {
    required String problemId,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    try {
      // Backend returns `{ mcq_ids, generated, withheld, ... }`, not an
      // artifact envelope. Load the first public MCQ for the learner.
      final Response<Object> response = await _client.postAi<Object>(
        ApiEndpoints.patientMcq(patientId),
        idempotencyKey: idempotencyKey,
        data: <String, Object>{'problem_id': problemId, 'count': 1},
        cancelToken: cancelToken,
      );
      final Map<String, dynamic> body = Json.map(response.data);
      final List<String> ids = Json.strings(body['mcq_ids']);
      if (ids.isEmpty) {
        return Err<McqDraft>(
          ApiFailure(
            const ApiError(
              code: 'ai_invalid_output',
              message: 'No question was generated.',
              status: 502,
            ),
          ),
        );
      }
      final Response<Object> mcq = await _client.get<Object>(
        ApiEndpoints.mcqGet(ids.first),
      );
      return Ok<McqDraft>(_draftFromPublic(Json.map(mcq.data), patientId));
    } on ApiError catch (error) {
      return Err<McqDraft>(ApiFailure(error));
    }
  }

  /// Wraps `GET /mcq/:id` public shape in the draft model the UI expects.
  static McqDraft _draftFromPublic(
    Map<String, dynamic> public,
    String patientId,
  ) {
    final String id = Json.string(
      public['mcq_id'] ?? public['id'] ?? public['question_id'],
    );
    final String status = Json.string(public['status'], 'ai_generated_unreviewed');
    final bool reviewed =
        status == 'approved' || status.toLowerCase() == 'reviewed';
    return McqDraft.fromEnvelope(
      AiEnvelope.fromJson(<String, dynamic>{
        'artifact_id': id,
        'operation': operation,
        'patient_id': patientId,
        'context_revision': 0,
        'status': 'draft',
        'review_state': reviewed ? 'reviewed' : 'draft',
        'outdated': false,
        'requires_review': !reviewed,
        'provider': '',
        'model': '',
        'prompt_version': '',
        'generation_ms': 0,
        'content': public,
      }),
    );
  }

  @override
  Future<Result<Map<String, dynamic>>> answer(
    String questionId, {
    required int selectedIndex,
  }) async {
    try {
      // Backend expects choice letters A–E, not a zero-based index.
      final String choice = String.fromCharCode(65 + selectedIndex);
      final Response<Object> response = await _client.post<Object>(
        ApiEndpoints.mcqAnswer(questionId),
        data: <String, String>{'choice': choice},
      );
      final Map<String, dynamic> body = Json.map(response.data);
      // The key may sit at the top or inside `content`.
      return Ok<Map<String, dynamic>>(
        body['content'] is Map ? Json.map(body['content']) : body,
      );
    } on ApiError catch (error) {
      return Err<Map<String, dynamic>>(ApiFailure(error));
    }
  }

  @override
  Future<Result<void>> report(
    String questionId, {
    required String reason,
  }) async {
    try {
      // Backend field is `note`.
      await _client.post<Object>(
        ApiEndpoints.mcqReport(questionId),
        data: <String, String>{'note': reason},
      );
      return const Ok<void>(null);
    } on ApiError catch (error) {
      return Err<void>(ApiFailure(error));
    }
  }

  @override
  Future<Result<List<McqDraft>>> questions(String patientId) async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.patientArtifacts(patientId),
        queryParameters: <String, dynamic>{'operation': operation},
      );
      final List<AiEnvelope> all = Json.itemsOf(
        response.data,
        'artifacts',
      ).map(AiEnvelope.fromJson).toList();
      final DateTime floor = DateTime.fromMillisecondsSinceEpoch(0);
      all.sort(
        (AiEnvelope a, AiEnvelope b) =>
            (b.createdAt ?? floor).compareTo(a.createdAt ?? floor),
      );
      final List<McqDraft> out = <McqDraft>[];
      for (final AiEnvelope e in all) {
        AiEnvelope full = e;
        if (e.content.isEmpty && e.artifactId.isNotEmpty) {
          // A list may carry only the header. Read the whole question.
          final Response<Object> one = await _client.get<Object>(
            ApiEndpoints.artifact(e.artifactId),
          );
          full = AiEnvelope.fromBody(one.data);
        }
        out.add(McqDraft.fromEnvelope(full));
      }
      return Ok<List<McqDraft>>(out);
    } on ApiError catch (error) {
      return Err<List<McqDraft>>(ApiFailure(error));
    }
  }
}
