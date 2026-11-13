import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/utils/app_log.dart';
import 'package:round_ai/features/chat/models/chat_stream_event.dart';
import 'package:round_ai/features/chat/services/sse_parser.dart';

/// SSE client for `GET /stream` (Bearer + `Last-Event-ID`).
abstract class ChatStreamClient {
  /// Opens one connection. Completes when the server closes, cancel fires, or
  /// a terminal error occurs. Does not log message bodies.
  Stream<ChatStreamEvent> connect({
    String? lastEventId,
    CancelToken? cancelToken,
    void Function()? onActivity,
  });

  void disconnect();

  void clear();
}

/// Placeholder / demo: no socket.
class NoOpChatStreamClient implements ChatStreamClient {
  @override
  Stream<ChatStreamEvent> connect({
    String? lastEventId,
    CancelToken? cancelToken,
    void Function()? onActivity,
  }) => const Stream<ChatStreamEvent>.empty();

  @override
  void disconnect() {}

  @override
  void clear() {}
}

/// Dio streamed `GET /stream`. Auth comes from [ApiClient]'s interceptor.
class DioChatStreamClient implements ChatStreamClient {
  DioChatStreamClient(this._api);

  final ApiClient _api;
  CancelToken? _active;

  @override
  Stream<ChatStreamEvent> connect({
    String? lastEventId,
    CancelToken? cancelToken,
    void Function()? onActivity,
  }) {
    final CancelToken token = cancelToken ?? CancelToken();
    _active = token;
    final StreamController<ChatStreamEvent> controller =
        StreamController<ChatStreamEvent>();

    () async {
      final SseParser parser = SseParser();
      try {
        final Response<ResponseBody> response = await _api.rawClient
            .get<ResponseBody>(
              ApiEndpoints.chatStream,
              cancelToken: token,
              options: Options(
                responseType: ResponseType.stream,
                // Long-lived; idle watchdog lives in ChatRealtimeController.
                receiveTimeout: Duration.zero,
                headers: <String, Object>{
                  'Accept': 'text/event-stream',
                  'Cache-Control': 'no-cache',
                  if (lastEventId != null && lastEventId.isNotEmpty)
                    'Last-Event-ID': lastEventId,
                },
              ),
            );

        final int? status = response.statusCode;
        if (status != null && status >= 400) {
          throw ApiError.fromResponse(status, null);
        }

        final Stream<Uint8List>? byteStream = response.data?.stream;
        if (byteStream == null) {
          throw const ApiError(code: 'stream_empty', message: '', status: 502);
        }

        await for (final Uint8List chunk in byteStream) {
          if (token.isCancelled) break;
          onActivity?.call();
          final String text = utf8.decode(chunk, allowMalformed: true);
          for (final ChatStreamEvent event in parser.add(
            text,
            onHeartbeat: onActivity,
          )) {
            if (controller.isClosed) return;
            controller.add(event);
          }
        }
      } on DioException catch (error) {
        if (CancelToken.isCancel(error) || token.isCancelled) {
          // Intentional disconnect.
        } else {
          final ApiError mapped = ApiClient.mapDioError(error);
          AppLog.line('[chat-sse] closed (${mapped.code})');
          if (!controller.isClosed) controller.addError(mapped);
        }
      } on ApiError catch (error) {
        AppLog.line('[chat-sse] closed (${error.code})');
        if (!controller.isClosed) controller.addError(error);
      } catch (error) {
        AppLog.line('[chat-sse] closed (${error.runtimeType})');
        if (!controller.isClosed) {
          controller.addError(
            const ApiError(code: 'network_error', message: '', status: null),
          );
        }
      } finally {
        parser.reset();
        if (!controller.isClosed) await controller.close();
        if (identical(_active, token)) _active = null;
      }
    }();

    controller.onCancel = () {
      if (!token.isCancelled) token.cancel('stream-cancel');
    };
    return controller.stream;
  }

  @override
  void disconnect() {
    final CancelToken? token = _active;
    _active = null;
    if (token != null && !token.isCancelled) {
      token.cancel('disconnect');
    }
  }

  @override
  void clear() => disconnect();
}
