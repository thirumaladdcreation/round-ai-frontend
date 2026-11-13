import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/evidence/models/evidence_result.dart';
import 'package:round_ai/features/evidence/repository/evidence_repository.dart';

class EvidenceRepositoryImpl implements EvidenceRepository {
  EvidenceRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<EvidenceResult>> search(
    String patientId, {
    String? problemId,
    String? topic,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    try {
      final String typed = topic?.trim() ?? '';
      final Response<Object> response = await _client.postAi<Object>(
        ApiEndpoints.patientEvidence(patientId),
        idempotencyKey: idempotencyKey,
        data: <String, String>{
          if (problemId != null && problemId.isNotEmpty)
            'problem_id': problemId
          else if (typed.isNotEmpty)
            'topic': typed,
        },
        cancelToken: cancelToken,
      );
      return Ok<EvidenceResult>(
        EvidenceResult.fromEnvelope(AiEnvelope.fromBody(response.data)),
      );
    } on ApiError catch (error) {
      return Err<EvidenceResult>(ApiFailure(error));
    }
  }
}
