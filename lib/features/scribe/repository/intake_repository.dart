import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/features/scribe/models/intake_result.dart';

/// Patient intake (dictate/photo) and note-field transcription.
abstract class IntakeRepository {
  /// Audio or image → chart source + pending facts.
  Future<Result<IntakeResult>> intake(
    String patientId, {
    required TempMedia media,
    required String idempotencyKey,
    DateTime? eventTime,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  });

  /// Audio → editable text only (for a note field mic).
  Future<Result<TranscribeResult>> transcribe({
    required TempMedia media,
    required String idempotencyKey,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  });
}
