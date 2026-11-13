import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/evidence/models/evidence_result.dart';
import 'package:round_ai/features/evidence/repository/evidence_repository.dart';

/// Demo builds keep the old evidence screen. Nothing is made up here: a
/// search says it is unavailable.
class DemoEvidenceRepository implements EvidenceRepository {
  @override
  Future<Result<EvidenceResult>> search(
    String patientId, {
    String? problemId,
    String? topic,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async => Err<EvidenceResult>(
    ApiFailure(
      const ApiError(code: 'ai_disabled', message: 'Demo build', status: 503),
    ),
  );
}
