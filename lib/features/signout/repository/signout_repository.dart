import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/signout/models/contingency.dart';

abstract class SignOutRepository {
  /// Writes a sign-out draft. [contingencies] are what the clinician typed.
  /// With none, the draft lists contingency instructions as missing.
  Future<Result<AiEnvelope>> generate(
    String patientId, {
    required List<Contingency> contingencies,
    required String idempotencyKey,
    CancelToken? cancelToken,
  });
}
