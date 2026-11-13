import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/utils/app_log.dart';
import 'package:round_ai/features/chat/models/chat_stream_event.dart';
import 'package:round_ai/features/chat/services/chat_stream_client.dart';

/// App-wide chat SSE: connect in foreground when signed in, disconnect in
/// background, reconnect with backoff + `Last-Event-ID`, dedupe, gap signals.
class ChatRealtimeController {
  ChatRealtimeController({
    required ChatStreamClient client,
    Random? random,
    this.idleTimeout = const Duration(seconds: 60),
    this.maxBackoff = const Duration(seconds: 30),
  }) : _client = client,
       _random = random ?? Random();

  final ChatStreamClient _client;
  final Random _random;
  final Duration idleTimeout;
  final Duration maxBackoff;

  final StreamController<ChatStreamEvent> _events =
      StreamController<ChatStreamEvent>.broadcast();
  final StreamController<ChatRealtimeGap> _gaps =
      StreamController<ChatRealtimeGap>.broadcast();
  final ValueNotifier<ChatRealtimeStatus> status =
      ValueNotifier<ChatRealtimeStatus>(ChatRealtimeStatus.idle);

  final LinkedHashSet<String> _seen = LinkedHashSet<String>();
  static const int _maxSeen = 2000;

  StreamSubscription<ChatStreamEvent>? _sub;
  CancelToken? _token;
  Timer? _idleTimer;
  Timer? _reconnectTimer;
  int _attempt = 0;
  bool _wantRunning = false;
  bool _foreground = false;
  bool _signedIn = false;
  bool _permanentStop = false;
  String? _lastEventId;
  int? _lastSeq;
  String? _activeChannelId;
  String? _currentUserId;

  Stream<ChatStreamEvent> get events => _events.stream;
  Stream<ChatRealtimeGap> get gaps => _gaps.stream;
  String? get lastEventId => _lastEventId;
  String? get activeChannelId => _activeChannelId;
  String? get currentUserId => _currentUserId;
  bool get isForeground => _foreground;

  void setSignedIn(bool value) {
    _signedIn = value;
    if (!value) {
      stop(clearCursor: true);
      return;
    }
    _permanentStop = false;
    _sync();
  }

  void setCurrentUserId(String? userId) => _currentUserId = userId;

  void setActiveChannel(String? channelId) {
    _activeChannelId = channelId;
  }

  void onForeground() {
    _foreground = true;
    _sync();
  }

  void onBackground() {
    _foreground = false;
    _tearDownConnection(reconnect: false);
    status.value = ChatRealtimeStatus.paused;
  }

  /// Starts the connect loop when chat is available and the app is active.
  void start() {
    if (!AppFeatures.chat) return;
    _wantRunning = true;
    _permanentStop = false;
    _sync();
  }

  void stop({bool clearCursor = false}) {
    _wantRunning = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _tearDownConnection(reconnect: false);
    if (clearCursor) {
      _lastEventId = null;
      _lastSeq = null;
      _seen.clear();
    }
    status.value = ChatRealtimeStatus.idle;
  }

  void clear() {
    stop(clearCursor: true);
    _activeChannelId = null;
    _currentUserId = null;
    _signedIn = false;
    _permanentStop = false;
  }

  void dispose() {
    clear();
    _events.close();
    _gaps.close();
    status.dispose();
  }

  void _sync() {
    if (_permanentStop || !_wantRunning || !_signedIn || !_foreground) {
      return;
    }
    if (_sub != null) return;
    _connect();
  }

  void _connect() {
    _tearDownConnection(reconnect: false);
    status.value = ChatRealtimeStatus.connecting;
    final CancelToken token = CancelToken();
    _token = token;
    AppLog.line('[chat-sse] connect (attempt $_attempt)');

    DateTime lastActivity = DateTime.now();
    void bumpActivity() {
      lastActivity = DateTime.now();
      _armIdle(() => lastActivity);
    }

    bumpActivity();

    _sub = _client
        .connect(
          lastEventId: _lastEventId,
          cancelToken: token,
          onActivity: bumpActivity,
        )
        .listen(
          (ChatStreamEvent event) {
            bumpActivity();
            _onEvent(event);
            if (status.value != ChatRealtimeStatus.live) {
              status.value = ChatRealtimeStatus.live;
              _attempt = 0;
            }
          },
          onError: (Object error, StackTrace _) {
            _onStreamEnded(error);
          },
          onDone: () {
            _onStreamEnded(null);
          },
          cancelOnError: false,
        );
  }

  void _armIdle(DateTime Function() lastActivity) {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(seconds: 5), (Timer t) {
      if (DateTime.now().difference(lastActivity()) > idleTimeout) {
        AppLog.line('[chat-sse] idle timeout');
        t.cancel();
        _tearDownConnection(reconnect: true);
      }
    });
  }

  void _onEvent(ChatStreamEvent event) {
    if (event.type == ChatStreamEventType.unknown) return;
    final String key =
        '${event.type.name}:${event.message.id}:${event.message.seq}';
    if (_seen.contains(key)) return;
    _seen.add(key);
    while (_seen.length > _maxSeen) {
      _seen.remove(_seen.first);
    }

    final int seq = event.message.seq;
    if (_lastSeq != null && seq > _lastSeq! + 1) {
      AppLog.line('[chat-sse] seq gap');
      if (!_gaps.isClosed) {
        _gaps.add(
          ChatRealtimeGap(
            fromSeq: _lastSeq!,
            toSeq: seq,
            channelId: event.message.channelId,
          ),
        );
      }
    }
    if (_lastSeq == null || seq > _lastSeq!) {
      _lastSeq = seq;
      _lastEventId = '$seq';
    } else if (event.eventId != null && event.eventId!.isNotEmpty) {
      // Keep cursor at the highest seq we have processed.
      final int? fromId = int.tryParse(event.eventId!);
      if (fromId != null && (_lastSeq == null || fromId > _lastSeq!)) {
        _lastSeq = fromId;
        _lastEventId = '$fromId';
      }
    }

    if (!_events.isClosed) _events.add(event);
  }

  void _onStreamEnded(Object? error) {
    _idleTimer?.cancel();
    _idleTimer = null;
    _sub = null;
    _token = null;

    if (_permanentStop) {
      status.value = ChatRealtimeStatus.stopped;
      return;
    }

    final ApiError? api = error is ApiError ? error : null;
    if (api != null && _isPermanent(api)) {
      _permanentStop = true;
      _wantRunning = false;
      status.value = ChatRealtimeStatus.stopped;
      AppLog.line('[chat-sse] permanent stop (${api.code})');
      return;
    }

    if (!_wantRunning || !_signedIn || !_foreground) {
      status.value = ChatRealtimeStatus.idle;
      return;
    }

    status.value = ChatRealtimeStatus.reconnecting;
    _scheduleReconnect();
  }

  bool _isPermanent(ApiError error) {
    return error.kind == ApiErrorKind.unauthenticated ||
        error.kind == ApiErrorKind.chatDisabled ||
        error.kind == ApiErrorKind.accessDenied;
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final int exp = _attempt.clamp(0, 5);
    _attempt += 1;
    final int cap = maxBackoff.inMilliseconds < 100
        ? 100
        : maxBackoff.inMilliseconds;
    final int grown = 500 * (1 << exp);
    final int baseMs = grown < cap ? grown : cap;
    final int jitter = _random.nextInt(400);
    final Duration delay = Duration(milliseconds: baseMs + jitter);
    AppLog.line('[chat-sse] reconnect in ${delay.inMilliseconds}ms');
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_wantRunning && _signedIn && _foreground && !_permanentStop) {
        _connect();
      }
    });
  }

  void _tearDownConnection({required bool reconnect}) {
    _idleTimer?.cancel();
    _idleTimer = null;
    final StreamSubscription<ChatStreamEvent>? sub = _sub;
    _sub = null;
    final CancelToken? token = _token;
    _token = null;
    unawaited(sub?.cancel());
    if (token != null && !token.isCancelled) {
      token.cancel('teardown');
    }
    _client.disconnect();
    if (reconnect &&
        _wantRunning &&
        _signedIn &&
        _foreground &&
        !_permanentStop) {
      status.value = ChatRealtimeStatus.reconnecting;
      _scheduleReconnect();
    }
  }
}

enum ChatRealtimeStatus {
  idle,
  connecting,
  live,
  reconnecting,
  paused,
  stopped,
}

class ChatRealtimeGap {
  const ChatRealtimeGap({
    required this.fromSeq,
    required this.toSeq,
    required this.channelId,
  });

  final int fromSeq;
  final int toSeq;
  final String channelId;
}
