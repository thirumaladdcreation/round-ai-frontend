import 'dart:convert';

import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/chat/models/chat_stream_event.dart';

/// Incremental SSE frame parser. Heartbeat comments (`: …`) are not events.
class SseParser {
  final StringBuffer _lineBuf = StringBuffer();
  String? _id;
  String? _event;
  final StringBuffer _data = StringBuffer();

  /// Feed raw UTF-8 chunk text. Yields completed events; [onHeartbeat] for
  /// comment lines / blank keep-alives so the client can reset idle timers.
  Iterable<ChatStreamEvent> add(
    String chunk, {
    void Function()? onHeartbeat,
  }) sync* {
    for (int i = 0; i < chunk.length; i++) {
      final String ch = chunk[i];
      if (ch == '\r') continue;
      if (ch != '\n') {
        _lineBuf.write(ch);
        continue;
      }
      final String line = _lineBuf.toString();
      _lineBuf.clear();
      final ChatStreamEvent? event = _handleLine(line, onHeartbeat: onHeartbeat);
      if (event != null) yield event;
    }
  }

  /// Flush a trailing incomplete line (optional; usually wait for `\n`).
  Iterable<ChatStreamEvent> flush({void Function()? onHeartbeat}) sync* {
    if (_lineBuf.isEmpty) return;
    final String line = _lineBuf.toString();
    _lineBuf.clear();
    final ChatStreamEvent? event = _handleLine(line, onHeartbeat: onHeartbeat);
    if (event != null) yield event;
  }

  ChatStreamEvent? _handleLine(
    String line, {
    void Function()? onHeartbeat,
  }) {
    if (line.isEmpty) {
      return _dispatch();
    }
    if (line.startsWith(':')) {
      onHeartbeat?.call();
      return null;
    }
    final int colon = line.indexOf(':');
    final String field = colon < 0 ? line : line.substring(0, colon);
    String value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);

    if (field == 'id') {
      _id = value;
    } else if (field == 'event') {
      _event = value;
    } else if (field == 'data') {
      if (_data.isNotEmpty) _data.write('\n');
      _data.write(value);
    }
    return null;
  }

  ChatStreamEvent? _dispatch() {
    if (_data.isEmpty) {
      _id = null;
      _event = null;
      return null;
    }
    final String raw = _data.toString();
    _data.clear();
    final String eventName = _event ?? 'message';
    final String? eventId = _id;
    _id = null;
    _event = null;

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    return ChatStreamEvent.fromSse(
      eventName: eventName,
      data: Json.map(decoded),
      eventId: eventId,
    );
  }

  void reset() {
    _lineBuf.clear();
    _data.clear();
    _id = null;
    _event = null;
  }
}
