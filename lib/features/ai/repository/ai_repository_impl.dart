import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/models/ask_reply.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/patient/models/fact.dart';

class AiRepositoryImpl implements AiRepository {
  AiRepositoryImpl(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ApiClient _client;
  final DateTime Function() _clock;

  static String _day(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Future<Result<AiEnvelope?>> latestSummary(String patientId) async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.patientArtifacts(patientId),
        queryParameters: <String, dynamic>{'operation': 'summarize_patient'},
      );
      final List<AiEnvelope> all = Json.itemsOf(
        response.data,
        'artifacts',
      ).map(AiEnvelope.fromJson).toList();
      if (all.isEmpty) return const Ok<AiEnvelope?>(null);
      // Newest first. An entry with no time sorts last.
      final DateTime floor = DateTime.fromMillisecondsSinceEpoch(0);
      all.sort(
        (AiEnvelope a, AiEnvelope b) =>
            (b.createdAt ?? floor).compareTo(a.createdAt ?? floor),
      );
      AiEnvelope latest = all.first;
      if (latest.content.isEmpty && latest.artifactId.isNotEmpty) {
        // A list may carry only the header. Read the full version.
        final Response<Object> full = await _client.get<Object>(
          ApiEndpoints.artifact(latest.artifactId),
        );
        latest = AiEnvelope.fromBody(full.data);
      }
      return Ok<AiEnvelope?>(latest);
    } on ApiError catch (error) {
      return Err<AiEnvelope?>(ApiFailure(error));
    }
  }

  @override
  Future<Result<AiEnvelope>> generateSummary(
    String patientId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response<Object> response = await _client.postAi<Object>(
        ApiEndpoints.patientSummary(patientId),
        idempotencyKey: idempotencyKey,
        data: <String, String>{'date': _day(_clock())},
        cancelToken: cancelToken,
      );
      return Ok<AiEnvelope>(AiEnvelope.fromBody(response.data));
    } on ApiError catch (error) {
      return Err<AiEnvelope>(ApiFailure(error));
    }
  }

  @override
  Future<Result<AiEnvelope>> markReviewed(String artifactId) async {
    try {
      final Response<Object> response = await _client.post<Object>(
        ApiEndpoints.artifactReview(artifactId),
      );
      final Map<String, dynamic> body = Json.map(response.data);
      if (body['artifact_id'] != null || body['artifact'] is Map) {
        return Ok<AiEnvelope>(AiEnvelope.fromBody(body));
      }
      // The reply is only an acknowledgement. Read the saved version.
      final Response<Object> saved = await _client.get<Object>(
        ApiEndpoints.artifact(artifactId),
      );
      return Ok<AiEnvelope>(AiEnvelope.fromBody(saved.data));
    } on ApiError catch (error) {
      return Err<AiEnvelope>(ApiFailure(error));
    }
  }

  @override
  Future<Result<SourcePassage>> factSource(String factId) async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.factSource(factId),
      );
      return Ok<SourcePassage>(SourcePassage.fromJson(Json.map(response.data)));
    } on ApiError catch (error) {
      return Err<SourcePassage>(ApiFailure(error));
    }
  }

  @override
  Future<Result<AskReply>> ask(
    String patientId, {
    required String question,
    required String idempotencyKey,
    String? topic,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response<Object> response = await _client.postAi<Object>(
        ApiEndpoints.patientAsk(patientId),
        idempotencyKey: idempotencyKey,
        data: <String, String>{
          'question': question,
          if (topic != null && topic.trim().isNotEmpty) 'topic': topic.trim(),
        },
        cancelToken: cancelToken,
      );
      return Ok<AskReply>(AskReply.fromJson(Json.map(response.data)));
    } on ApiError catch (error) {
      return Err<AskReply>(ApiFailure(error));
    }
  }
}
