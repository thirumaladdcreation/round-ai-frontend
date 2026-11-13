import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/signout/models/contingency.dart';
import 'package:round_ai/features/signout/repository/signout_repository.dart';

/// Demo builds keep the old sign-out screen. This answers honestly.
class DemoSignOutRepository implements SignOutRepository {
  @override
  Future<Result<AiEnvelope>> generate(
    String patientId, {
    required List<Contingency> contingencies,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async => Err<AiEnvelope>(
    ApiFailure(
      const ApiError(code: 'ai_disabled', message: 'Demo build', status: 503),
    ),
  );
}
