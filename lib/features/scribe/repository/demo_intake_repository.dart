import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/scribe/models/intake_result.dart';
import 'package:round_ai/features/scribe/repository/intake_repository.dart';

/// Demo build has no transcription/OCR. Fail honestly.
class DemoIntakeRepository implements IntakeRepository {
  static Failure get _off => ApiFailure(
    const ApiError(code: 'ai_disabled', message: 'Demo build', status: 503),
  );

  @override
  Future<Result<IntakeResult>> intake(
    String patientId, {
    required TempMedia media,
    required String idempotencyKey,
    DateTime? eventTime,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    await media.delete();
    return Err<IntakeResult>(_off);
  }

  @override
  Future<Result<TranscribeResult>> transcribe({
    required TempMedia media,
    required String idempotencyKey,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    await media.delete();
    return Err<TranscribeResult>(_off);
  }
}
