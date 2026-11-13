import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A scripted backend. Records each request and answers from [handler].
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FakeReply Function(RequestOptions options) handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final FakeReply reply = handler(options);
    if (reply.error != null) throw reply.error!;
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeReply {
  const FakeReply(this.status, this.body) : error = null;

  /// Fails like a dropped connection instead of answering.
  FakeReply.fail(DioException this.error) : status = 0, body = null;

  final int status;
  final Object? body;
  final DioException? error;
}

Dio fakeDio(FakeAdapter adapter) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://backend.test'));
  dio.httpClientAdapter = adapter;
  return dio;
}
