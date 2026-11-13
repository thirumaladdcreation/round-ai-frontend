import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/patient/models/chart_source.dart';
import 'package:round_ai/features/patient/models/fact.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository.dart';

class ChartDataRepositoryImpl implements ChartDataRepository {
  ChartDataRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<ChartSource>> addSource(
    String patientId, {
    required ChartSourceKind kind,
    required DateTime time,
    required String text,
  }) async {
    try {
      final response = await _client.post<Object>(
        ApiEndpoints.patientSources(patientId),
        data: <String, String>{
          'kind': kind.wire,
          'event_time': time.toUtc().toIso8601String(),
          'text': text,
        },
      );
      Map<String, dynamic> body = Json.map(response.data);
      if (body['source'] is Map) body = Json.map(body['source']);
      return Ok<ChartSource>(ChartSource.fromJson(body));
    } on ApiError catch (error) {
      return Err<ChartSource>(ApiFailure(error));
    }
  }

  @override
  Future<Result<List<ChartSource>>> listSources(String patientId) async {
    try {
      final response = await _client.get<Object>(
        ApiEndpoints.patientSources(patientId),
      );
      return Ok<List<ChartSource>>(
        Json.itemsOf(response.data, 'sources').map(ChartSource.fromJson).toList(),
      );
    } on ApiError catch (error) {
      return Err<List<ChartSource>>(ApiFailure(error));
    }
  }

  @override
  Future<Result<void>> extract(String patientId, String sourceId) async {
    try {
      await _client.post<Object>(
        ApiEndpoints.sourceExtract(patientId, sourceId),
      );
      return const Ok<void>(null);
    } on ApiError catch (error) {
      return Err<void>(ApiFailure(error));
    }
  }

  @override
  Future<Result<List<Fact>>> pendingFacts(String patientId) async {
    try {
      final response = await _client.get<Object>(
        ApiEndpoints.patientFacts(patientId),
        queryParameters: <String, dynamic>{'status': 'pending'},
      );
      return Ok<List<Fact>>(
        Json.itemsOf(response.data, 'facts').map(Fact.fromJson).toList(),
      );
    } on ApiError catch (error) {
      return Err<List<Fact>>(ApiFailure(error));
    }
  }

  @override
  Future<Result<void>> decide(
    String patientId,
    List<String> factIds, {
    required bool confirm,
  }) async {
    if (factIds.isEmpty) return const Ok<void>(null);
    try {
      await _client.post<Object>(
        ApiEndpoints.patientFactsReview(patientId),
        data: <String, Object>{
          'fact_ids': factIds,
          'status': confirm ? 'confirmed' : 'rejected',
        },
      );
      return const Ok<void>(null);
    } on ApiError catch (error) {
      return Err<void>(ApiFailure(error));
    }
  }

  @override
  Future<Result<void>> addFact(String patientId, NewFact fact) async {
    try {
      await _client.post<Object>(
        ApiEndpoints.patientFacts(patientId),
        data: fact.toJson(),
      );
      return const Ok<void>(null);
    } on ApiError catch (error) {
      return Err<void>(ApiFailure(error));
    }
  }
}
