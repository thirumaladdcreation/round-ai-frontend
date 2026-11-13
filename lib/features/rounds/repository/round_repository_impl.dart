import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/rounds/models/prepare_result.dart';
import 'package:round_ai/features/rounds/models/presentation_draft.dart';
import 'package:round_ai/features/rounds/models/round_brief.dart';
import 'package:round_ai/features/rounds/models/round_reminder.dart';
import 'package:round_ai/features/rounds/repository/round_repository.dart';

class RoundRepositoryImpl implements RoundRepository {
  RoundRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<RoundBrief>> loadBrief({String? date, String? teamId}) async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.roundBrief,
        queryParameters: <String, dynamic>{
          if (date != null && date.isNotEmpty) 'date': date,
          if (teamId != null && teamId.isNotEmpty) 'team_id': teamId,
        },
      );
      return Ok<RoundBrief>(RoundBrief.fromJson(Json.map(response.data)));
    } on ApiError catch (error) {
      return Err<RoundBrief>(ApiFailure(error));
    }
  }

  @override
  Future<Result<PreparePresentationsResult>> preparePresentations({
    required List<String> patientIds,
    required String idempotencyKey,
    String? date,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response<Object> response = await _client.postAi<Object>(
        ApiEndpoints.roundBriefPrepare,
        idempotencyKey: idempotencyKey,
        data: <String, Object?>{
          'patient_ids': patientIds,
          if (date != null && date.isNotEmpty) 'date': date,
        },
        cancelToken: cancelToken,
      );
      return Ok<PreparePresentationsResult>(
        PreparePresentationsResult.fromJson(Json.map(response.data)),
      );
    } on ApiError catch (error) {
      return Err<PreparePresentationsResult>(ApiFailure(error));
    }
  }

  @override
  Future<Result<PresentationResult>> present(
    String patientId, {
    required String idempotencyKey,
    String? date,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response<Object> response = await _client.postAi<Object>(
        ApiEndpoints.patientPresent(patientId),
        idempotencyKey: idempotencyKey,
        data: <String, Object?>{
          if (date != null && date.isNotEmpty) 'date': date,
        },
        cancelToken: cancelToken,
      );
      return Ok<PresentationResult>(
        PresentationResult.fromEnvelope(AiEnvelope.fromBody(response.data)),
      );
    } on ApiError catch (error) {
      return Err<PresentationResult>(ApiFailure(error));
    }
  }

  @override
  Future<Result<ReminderListResult>> loadReminders(
    String patientId, {
    String? date,
  }) async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.patientReminders(patientId),
        queryParameters: <String, dynamic>{
          if (date != null && date.isNotEmpty) 'date': date,
        },
      );
      return Ok<ReminderListResult>(
        ReminderListResult.fromJson(Json.map(response.data)),
      );
    } on ApiError catch (error) {
      return Err<ReminderListResult>(ApiFailure(error));
    }
  }

  @override
  Future<Result<ReminderAck>> ackReminder(
    String patientId,
    String ruleId, {
    required ReminderAckState state,
    String? note,
    String? date,
  }) async {
    try {
      final Response<Object> response = await _client.post<Object>(
        ApiEndpoints.reminderAck(patientId, ruleId),
        data: <String, Object?>{
          'state': state.wire,
          if (note != null && note.isNotEmpty) 'note': note,
          if (date != null && date.isNotEmpty) 'date': date,
        },
      );
      return Ok<ReminderAck>(ReminderAck.fromJson(Json.map(response.data)));
    } on ApiError catch (error) {
      return Err<ReminderAck>(ApiFailure(error));
    }
  }
}
