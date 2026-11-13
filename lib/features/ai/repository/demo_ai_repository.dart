import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/models/ask_reply.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/patient/models/fact.dart';

/// Demo builds have no backend, so nothing is generated here. The demo
/// screens keep their own canned content; this only answers honestly.
class DemoAiRepository implements AiRepository {
  static Failure get _off => ApiFailure(
    const ApiError(code: 'ai_disabled', message: 'Demo build', status: 503),
  );

  @override
  Future<Result<AiEnvelope?>> latestSummary(String patientId) async =>
      const Ok<AiEnvelope?>(null);

  @override
  Future<Result<AiEnvelope>> generateSummary(
    String patientId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async => Err<AiEnvelope>(_off);

  @override
  Future<Result<AiEnvelope>> markReviewed(String artifactId) async =>
      Err<AiEnvelope>(_off);

  @override
  Future<Result<SourcePassage>> factSource(String factId) async =>
      Err<SourcePassage>(_off);

  @override
  Future<Result<AskReply>> ask(
    String patientId, {
    required String question,
    required String idempotencyKey,
    String? topic,
    CancelToken? cancelToken,
  }) async => Err<AskReply>(_off);
}
