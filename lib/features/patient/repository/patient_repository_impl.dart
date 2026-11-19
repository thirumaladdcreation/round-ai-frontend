import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/models/plan_structured.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';

class PatientRepositoryImpl implements PatientRepository {
  PatientRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<PatientDetail>> loadDetail(String patientId) async {
    try {
      final response = await _client.get<Object>(
        ApiEndpoints.patient(patientId),
      );
      Map<String, dynamic> body = Json.map(response.data);
      if (body['patient'] is Map) {
        body = <String, dynamic>{...body, ...Json.map(body['patient'])};
      }
      return Ok<PatientDetail>(PatientDetail.fromJson(body));
    } on ApiError catch (error) {
      return Err<PatientDetail>(ApiFailure(error));
    }
  }

  @override
  Future<Result<PatientChanges>> loadChanges(String patientId) async {
    try {
      final response = await _client.get<Object>(
        ApiEndpoints.patientChanges(patientId),
      );
      return Ok<PatientChanges>(
        PatientChanges.fromJson(Json.map(response.data)),
      );
    } on ApiError catch (error) {
      return Err<PatientChanges>(ApiFailure(error));
    }
  }

  @override
  Future<Result<void>> savePlan(String patientId, List<String> lines) async {
    final String text = lines
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .join('\n');
    if (text.isEmpty) {
      return Err<void>(
        ApiFailure(
          const ApiError(
            code: 'text_required',
            message: 'Plan text is required.',
          ),
        ),
      );
    }
    try {
      // Backend: PUT { text, plan_date? } — one string, not a list field.
      await _client.put<Object>(
        ApiEndpoints.patientPlan(patientId),
        data: <String, String>{'text': text},
      );
      return const Ok<void>(null);
    } on ApiError catch (error) {
      return Err<void>(ApiFailure(error));
    }
  }

  @override
  Future<Result<void>> saveStructuredPlan(
    String patientId,
    PlanStructured plan,
  ) async {
    final List<PlanItem> items = plan.items
        .where((PlanItem i) => !i.isEmpty)
        .toList();
    if (items.isEmpty) {
      return Err<void>(
        ApiFailure(
          const ApiError(
            code: 'text_required',
            message: 'Enter at least one Assessment and Plan item.',
          ),
        ),
      );
    }
    try {
      await _client.put<Object>(
        ApiEndpoints.patientPlan(patientId),
        data: <String, Object>{
          'include_icd': plan.includeIcd,
          'items': items.map((PlanItem i) => i.toJson()).toList(),
        },
      );
      return const Ok<void>(null);
    } on ApiError catch (error) {
      return Err<void>(ApiFailure(error));
    }
  }
}
