import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/problems/models/coding_suggestion.dart';
import 'package:round_ai/features/problems/repository/problems_repository.dart';

class ProblemsRepositoryImpl implements ProblemsRepository {
  ProblemsRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<Problem>>> list(String patientId) async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.patientProblems(patientId),
      );
      return Ok<List<Problem>>(
        Json.itemsOf(response.data, 'problems').map(Problem.fromJson).toList(),
      );
    } on ApiError catch (error) {
      return Err<List<Problem>>(ApiFailure(error));
    }
  }

  @override
  Future<Result<List<Problem>>> suggest(
    String patientId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response<Object> response = await _client.postAi<Object>(
        ApiEndpoints.problemsSuggest(patientId),
        idempotencyKey: idempotencyKey,
        cancelToken: cancelToken,
      );
      // A bare list, `{problems: []}`, or an AI envelope with the list in
      // `content`.
      final Object? body = response.data;
      List<Map<String, dynamic>> items = Json.itemsOf(body, 'problems');
      if (items.isEmpty && body is Map) {
        final Map<String, dynamic> content = Json.map(body['content']);
        items = Json.maps(content['problems'] ?? content['suggestions']);
      }
      return Ok<List<Problem>>(
        items
            .map(Problem.fromJson)
            .map(_asSuggestion)
            .where((Problem p) => p.label.isNotEmpty)
            .toList(),
      );
    } on ApiError catch (error) {
      return Err<List<Problem>>(ApiFailure(error));
    }
  }

  /// A problem that comes back from a suggest call is a suggestion, whatever
  /// state text it carries. Only a clinician's decision makes it anything else.
  static Problem _asSuggestion(Problem p) {
    if (p.state == ProblemState.documented ||
        p.state == ProblemState.suggested) {
      return p;
    }
    return p.copyWith(state: ProblemState.suggested, clearCodeSuggestion: true);
  }

  @override
  Future<Result<void>> decide(
    String patientId,
    String problemId,
    ProblemAction action,
  ) async {
    try {
      await _client.post<Object>(
        ApiEndpoints.problemDecision(patientId, problemId),
        data: <String, String>{'action': action.wire},
      );
      return const Ok<void>(null);
    } on ApiError catch (error) {
      return Err<void>(ApiFailure(error));
    }
  }

  @override
  Future<Result<CodingSuggestResult>> suggestCoding(
    String patientId, {
    required String problemId,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response<Object> response = await _client.postAi<Object>(
        ApiEndpoints.codingSuggest(patientId),
        idempotencyKey: idempotencyKey,
        data: <String, String>{'problem_id': problemId},
        cancelToken: cancelToken,
      );
      final AiEnvelope envelope = AiEnvelope.fromBody(response.data);
      return Ok<CodingSuggestResult>(
        CodingSuggestResult.fromEnvelope(
          artifactId: envelope.artifactId,
          content: envelope.content,
        ),
      );
    } on ApiError catch (error) {
      return Err<CodingSuggestResult>(ApiFailure(error));
    }
  }

  @override
  Future<Result<AcceptedCodeSuggestion>> acceptCoding(
    String patientId,
    String problemId, {
    required String code,
    String? artifactId,
  }) async {
    try {
      final Response<Object> response = await _client.post<Object>(
        ApiEndpoints.codingAccept(patientId, problemId),
        data: <String, String>{
          'code': code,
          if (artifactId != null && artifactId.isNotEmpty)
            'artifact_id': artifactId,
        },
      );
      final Map<String, dynamic> body = Json.map(response.data);
      final Object? raw = body['code_suggestion'] ?? body;
      return Ok<AcceptedCodeSuggestion>(AcceptedCodeSuggestion.fromJson(raw));
    } on ApiError catch (error) {
      return Err<AcceptedCodeSuggestion>(ApiFailure(error));
    }
  }
}
