import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/media/media_limits.dart';
import 'package:round_ai/core/media/media_uploader.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/scribe/models/intake_result.dart';
import 'package:round_ai/features/scribe/repository/intake_repository.dart';

class IntakeRepositoryImpl implements IntakeRepository {
  IntakeRepositoryImpl(ApiClient client, {MediaUploader? uploader})
    : _uploader = uploader ?? MediaUploader(client);

  final MediaUploader _uploader;

  @override
  Future<Result<IntakeResult>> intake(
    String patientId, {
    required TempMedia media,
    required String idempotencyKey,
    DateTime? eventTime,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final Response<Object> response = await withTempMediaCleanup(
        media,
        (TempMedia m) => _uploader.upload(
          path: ApiEndpoints.patientIntake(patientId),
          idempotencyKey: idempotencyKey,
          media: m,
          eventTime: eventTime?.toUtc().toIso8601String(),
          filename: m.kind == MediaKind.audio
              ? (m.mimeType.contains('wav') ? 'dictation.wav' : 'dictation.m4a')
              : 'photo.jpg',
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
        ),
      );
      return Ok<IntakeResult>(IntakeResult.fromJson(Json.map(response.data)));
    } on ApiError catch (error) {
      return Err<IntakeResult>(ApiFailure(error));
    }
  }

  @override
  Future<Result<TranscribeResult>> transcribe({
    required TempMedia media,
    required String idempotencyKey,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final Response<Object> response = await withTempMediaCleanup(
        media,
        (TempMedia m) => _uploader.upload(
          path: ApiEndpoints.transcribe,
          idempotencyKey: idempotencyKey,
          media: m,
          filename: m.mimeType.contains('wav')
              ? 'dictation.wav'
              : 'dictation.m4a',
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
        ),
      );
      return Ok<TranscribeResult>(
        TranscribeResult.fromJson(Json.map(response.data)),
      );
    } on ApiError catch (error) {
      return Err<TranscribeResult>(ApiFailure(error));
    }
  }
}
