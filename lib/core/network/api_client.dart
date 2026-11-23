import 'package:dio/dio.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/constants/app_constants.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/api_log_interceptor.dart';
import 'package:round_ai/core/network/auth_interceptor.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/core/utils/app_log.dart';

/// Thin Dio wrapper. Callers get a [Response] or an [ApiError].
///
/// Normal calls use a short timeout. [postAi] is the only call with a long
/// timeout, and it always sends an `Idempotency-Key`.
class ApiClient {
  ApiClient({
    required SessionStore session,
    Future<void> Function()? onUnauthorized,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: AppEnvironment.baseUrl,
               connectTimeout: AppConstants.connectTimeout,
               receiveTimeout: AppConstants.receiveTimeout,
               sendTimeout: AppConstants.connectTimeout,
               headers: const <String, Object>{
                 'Accept': 'application/json',
                 'Content-Type': 'application/json',
               },
             ),
           ) {
    _dio.interceptors.add(
      AuthInterceptor(session, onUnauthorized: onUnauthorized),
    );
    // Debug builds only, and only with ENABLE_NETWORK_LOGS. Never in release.
    if (AppEnvironment.isNetworkLoggingEnabled) {
      _dio.interceptors.add(ApiLogInterceptor());
    }
  }

  final Dio _dio;

  Dio get rawClient => _dio;

  /// Fire-and-forget ping so a sleeping Fly trial machine can wake before login.
  ///
  /// When [onHealth] is set, passes the parsed health JSON (provider/model).
  void wakeBackend({void Function(Map<String, dynamic> health)? onHealth}) {
    () async {
      try {
        final Response<Object> response = await _dio.get<Object>(
          ApiEndpoints.health,
          options: Options(
            connectTimeout: AppConstants.connectTimeout,
            receiveTimeout: AppConstants.connectTimeout,
          ),
        );
        final Object? data = response.data;
        if (onHealth != null && data is Map) {
          onHealth(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        AppLog.line('[api] wakeBackend: $e');
      }
    }();
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _send<T>(
      () => _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _send<T>(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// POST for AI endpoints. Long timeout, cancellable, and idempotent:
  /// create [idempotencyKey] once per user action and reuse it on retry.
  Future<Response<T>> postAi<T>(
    String path, {
    required String idempotencyKey,
    Object? data,
    CancelToken? cancelToken,
  }) {
    return post<T>(
      path,
      data: data,
      cancelToken: cancelToken,
      options: Options(
        receiveTimeout: AppConstants.aiReceiveTimeout,
        headers: <String, Object>{IdempotencyKey.header: idempotencyKey},
      ),
    );
  }

  /// Multipart AI upload (audio/image). Progress is reported; cancel works.
  /// Do not put patient identifiers in the filename.
  Future<Response<T>> postAiMultipart<T>(
    String path, {
    required String idempotencyKey,
    required FormData data,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onSendProgress,
  }) {
    return _send<T>(
      () => _dio.post<T>(
        path,
        data: data,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: Options(
          // Dio sets multipart Content-Type with the boundary itself.
          contentType: null,
          sendTimeout: AppConstants.uploadTimeout,
          receiveTimeout: AppConstants.uploadTimeout,
          headers: <String, Object>{IdempotencyKey.header: idempotencyKey},
        ),
      ),
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _send<T>(
      () => _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _send<T>(
      () => _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _send<T>(
      () => _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  Future<Response<T>> _send<T>(Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Turns a Dio failure into an [ApiError]. Public so it can be tested.
  static ApiError mapDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiError.timeout();
      case DioExceptionType.cancel:
        return const ApiError.cancelled();
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const ApiError.network();
      case DioExceptionType.badResponse:
        return ApiError.fromResponse(
          error.response?.statusCode,
          error.response?.data,
          requestId: _headerRequestId(error.response?.headers),
        );
    }
  }

  static String? _headerRequestId(Headers? headers) {
    if (headers == null) return null;
    return headers.value('x-request-id') ?? headers.value('X-Request-Id');
  }
}
