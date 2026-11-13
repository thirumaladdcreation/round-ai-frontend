import 'package:dio/dio.dart';
import 'package:round_ai/core/media/media_limits.dart';
import 'package:round_ai/core/media/media_validator.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_error.dart';

/// Builds the multipart body the backend `resolveMediaPayload` expects and
/// posts it. The temp file is **not** deleted here — wrap the call in
/// [withTempMediaCleanup].
class MediaUploader {
  MediaUploader(this._client);

  final ApiClient _client;

  /// Field name for the file part. Backend busboy accepts any single file.
  static const String fileField = 'file';

  /// Validates then uploads. [filename] must not contain a patient name.
  Future<Response<Object>> upload({
    required String path,
    required String idempotencyKey,
    required TempMedia media,
    String? eventTime,
    String? sourceKind,
    String? teamId,
    String filename = 'capture.bin',
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final int length = await media.length();
    final ApiError? bad = MediaValidator.check(
      kind: media.kind,
      mimeType: media.mimeType,
      byteLength: length,
    );
    if (bad != null) throw bad;

    final FormData data = FormData.fromMap(<String, dynamic>{
      'kind': media.kind.wire,
      // Also sent as a field so base64 clients and multipart share one shape.
      'mime_type': media.mimeType,
      if (eventTime != null && eventTime.isNotEmpty) 'event_time': eventTime,
      if (sourceKind != null && sourceKind.isNotEmpty)
        'source_kind': sourceKind,
      if (teamId != null && teamId.isNotEmpty) 'team_id': teamId,
      fileField: await MultipartFile.fromFile(
        media.file.path,
        filename: filename,
      ),
    });

    return _client.postAiMultipart<Object>(
      path,
      idempotencyKey: idempotencyKey,
      data: data,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
  }
}
