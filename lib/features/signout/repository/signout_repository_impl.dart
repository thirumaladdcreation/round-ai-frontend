import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/signout/models/contingency.dart';
import 'package:round_ai/features/signout/repository/signout_repository.dart';

class SignOutRepositoryImpl implements SignOutRepository {
  SignOutRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<AiEnvelope>> generate(
    String patientId, {
    required List<Contingency> contingencies,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response<Object> response = await _client.postAi<Object>(
        ApiEndpoints.patientSignout(patientId),
        idempotencyKey: idempotencyKey,
        data: <String, Object>{
          'contingencies': <Map<String, String>>[
            for (final Contingency c in contingencies) c.toJson(),
          ],
        },
        cancelToken: cancelToken,
      );
      return Ok<AiEnvelope>(AiEnvelope.fromBody(response.data));
    } on ApiError catch (error) {
      return Err<AiEnvelope>(ApiFailure(error));
    }
  }
}
