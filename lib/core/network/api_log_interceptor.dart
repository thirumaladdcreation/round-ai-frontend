import 'package:dio/dio.dart';
import 'package:round_ai/core/utils/app_log.dart';

/// Debug-only request logger. It shows the method, the path, the status and the
/// SHAPE of a body (its field names and sizes). Values are never printed, since
/// a body can hold patient data or typed text. Auth and credential headers are
/// redacted. Release and production builds never log at all.
class ApiLogInterceptor extends Interceptor {
  static const Set<String> _sensitiveKeys = <String>{
    'authorization',
    'password',
    'confirmpassword',
    'token',
    'accesstoken',
    'refreshtoken',
    'authtoken',
    'fcmtoken',
    'otp',
    'pin',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLog.section('API REQUEST', <String, Object?>{
      'METHOD': options.method,
      'PATH': options.uri.path,
      'HEADERS': _redactHeaders(options.headers),
      'QUERY': options.queryParameters.keys.toList(),
      'BODY': describe(options.data),
    });
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    AppLog.section('API RESPONSE', <String, Object?>{
      'STATUS': '${response.statusCode} ${response.statusMessage ?? ''}'.trim(),
      'PATH': response.requestOptions.uri.path,
      'BODY': describe(response.data),
    });
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLog.section('API ERROR', <String, Object?>{
      'TYPE': err.type.name,
      'STATUS': err.response?.statusCode,
      'PATH': err.requestOptions.uri.path,
      'BODY': describe(err.response?.data),
    });
    handler.next(err);
  }

  /// What a body looks like, without what it says.
  static String describe(Object? data) {
    if (data == null) return 'none';
    if (data is FormData) {
      return 'form(fields: ${data.fields.map((e) => e.key).join(', ')}; '
          'files: ${data.files.length})';
    }
    if (data is Map) {
      return 'object(${data.keys.map((Object? k) => k.toString()).join(', ')})';
    }
    if (data is List) return 'list(${data.length})';
    if (data is String) return 'text(${data.length} chars)';
    return data.runtimeType.toString();
  }

  static Map<String, Object?> _redactHeaders(Map<dynamic, dynamic> source) {
    final Map<String, Object?> out = <String, Object?>{};
    source.forEach((dynamic key, dynamic value) {
      final String k = key.toString();
      out[k] = _isSensitive(k) ? '***' : value;
    });
    return out;
  }

  static bool _isSensitive(String key) {
    final String normalized = key.toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );
    return _sensitiveKeys.contains(normalized);
  }
}
