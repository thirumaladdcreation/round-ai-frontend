import 'package:dio/dio.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/storage/session_store.dart';

/// Adds the Bearer token to requests. There is no refresh endpoint, so a 401
/// on a request that carried a token ends the session: [onUnauthorized]
/// clears it and sends the user to sign-in.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._session, {this.onUnauthorized});

  static const String _sentTokenKey = 'sent_token';

  final SessionStore _session;
  final Future<void> Function()? onUnauthorized;

  bool _ending = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final String? token = _session.token;
    final bool isLogin = options.path == ApiEndpoints.login;
    if (!isLogin && token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      options.extra[_sentTokenKey] = true;
    }
    if (options.data is FormData) {
      options.headers.remove(Headers.contentTypeHeader);
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final bool sentToken = err.requestOptions.extra[_sentTokenKey] == true;
    if (err.response?.statusCode == 401 && sentToken && !_ending) {
      _ending = true;
      try {
        await onUnauthorized?.call();
      } finally {
        _ending = false;
      }
    }
    handler.next(err);
  }
}
