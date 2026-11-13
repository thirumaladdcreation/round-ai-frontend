import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/models/ask_reply.dart';
import 'package:round_ai/features/patient/models/fact.dart';

/// Every AI call goes through the backend. The app holds no model keys.
///
/// The POSTs that generate something take an [idempotencyKey]. Create it once
/// per user action and pass the same one when that action is retried.
abstract class AiRepository {
  /// The newest saved summary, or `null` when none was made yet.
  Future<Result<AiEnvelope?>> latestSummary(String patientId);

  Future<Result<AiEnvelope>> generateSummary(
    String patientId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  /// Marks one version reviewed. The backend refuses when the chart changed
  /// or sections still have flags or missing text.
  Future<Result<AiEnvelope>> markReviewed(String artifactId);

  /// The passage and source behind a chart fact.
  Future<Result<SourcePassage>> factSource(String factId);

  /// One question about one patient. [topic] is typed or picked by the user.
  Future<Result<AskReply>> ask(
    String patientId, {
    required String question,
    required String idempotencyKey,
    String? topic,
    CancelToken? cancelToken,
  });
}
