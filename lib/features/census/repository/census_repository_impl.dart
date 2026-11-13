import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/media/media_limits.dart';
import 'package:round_ai/core/media/media_uploader.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/census/models/census_intake.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';

/// `GET /patients` returns every team of the user. The list is cut to the
/// selected team here and ordered by sort_order, then room.
class CensusRepositoryImpl implements CensusRepository {
  CensusRepositoryImpl(this._client, this._storage, {MediaUploader? uploader})
    : _uploader = uploader ?? MediaUploader(_client);

  final ApiClient _client;
  final AppStorage _storage;
  final MediaUploader _uploader;

  @override
  Future<Result<List<PatientSummary>>> loadPatients() async {
    try {
      final response = await _client.get<Object>(ApiEndpoints.patients);
      final List<PatientSummary> all = Json.itemsOf(
        response.data,
        'patients',
      ).map(PatientSummary.fromJson).toList();
      final String? teamId = _storage.selectedTeamId;
      final List<PatientSummary> mine = teamId == null
          ? all
          : all.where((PatientSummary p) => p.teamId == teamId).toList();
      mine.sort(PatientSummary.compareCensus);
      return Ok<List<PatientSummary>>(mine);
    } on ApiError catch (error) {
      return Err<List<PatientSummary>>(ApiFailure(error));
    }
  }

  @override
  Future<Result<PatientSummary>> addPatient(NewPatient patient) async {
    try {
      final response = await _client.post<Object>(
        ApiEndpoints.patients,
        data: patient.toJson(),
      );
      Map<String, dynamic> body = Json.map(response.data);
      if (body['patient'] is Map) body = Json.map(body['patient']);
      return Ok<PatientSummary>(PatientSummary.fromJson(body));
    } on ApiError catch (error) {
      return Err<PatientSummary>(ApiFailure(error));
    }
  }

  @override
  Future<Result<CensusIntakeProposal>> intakeCensus({
    required TempMedia media,
    required String idempotencyKey,
    String? teamId,
    CancelToken? cancelToken,
  }) async {
    try {
      final String? team = teamId ?? _storage.selectedTeamId;
      final Response<Object> response = await withTempMediaCleanup(
        media,
        (TempMedia m) => _uploader.upload(
          path: ApiEndpoints.censusIntake,
          idempotencyKey: idempotencyKey,
          media: m,
          teamId: team,
          filename: m.kind == MediaKind.audio ? 'census.m4a' : 'census.jpg',
          cancelToken: cancelToken,
        ),
      );
      return Ok<CensusIntakeProposal>(
        CensusIntakeProposal.fromJson(Json.map(response.data)),
      );
    } on ApiError catch (error) {
      return Err<CensusIntakeProposal>(ApiFailure(error));
    }
  }

  @override
  Future<Result<CensusConfirmResult>> confirmCensus(
    String intakeId, {
    required List<ProposedCensusPatient> items,
  }) async {
    try {
      final Response<Object> response = await _client.post<Object>(
        ApiEndpoints.censusIntakeConfirm(intakeId),
        data: <String, Object>{
          'items': <Map<String, Object>>[
            for (final ProposedCensusPatient p in items) p.toConfirmItem(),
          ],
        },
      );
      return Ok<CensusConfirmResult>(
        CensusConfirmResult.fromJson(Json.map(response.data)),
      );
    } on ApiError catch (error) {
      return Err<CensusConfirmResult>(ApiFailure(error));
    }
  }

  @override
  Future<Result<CensusExport>> exportCensus({String? teamId}) async {
    try {
      final String? team = teamId ?? _storage.selectedTeamId;
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.censusExport,
        queryParameters: team == null || team.isEmpty
            ? null
            : <String, dynamic>{'team_id': team},
      );
      return Ok<CensusExport>(CensusExport.fromJson(Json.map(response.data)));
    } on ApiError catch (error) {
      return Err<CensusExport>(ApiFailure(error));
    }
  }

  @override
  Future<Result<void>> setSortOrder(String patientId, int sortOrder) async {
    try {
      await _client.patch<Object>(
        ApiEndpoints.patient(patientId),
        data: <String, int>{'sort_order': sortOrder},
      );
      return const Ok<void>(null);
    } on ApiError catch (error) {
      return Err<void>(ApiFailure(error));
    }
  }
}
