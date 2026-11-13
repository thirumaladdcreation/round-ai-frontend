import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';

/// SSE event names from `GET /stream`. Heartbeat comments are not events.
enum ChatStreamEventType { message, messageEdited, messageDeleted, unknown }

/// One parsed SSE payload. [eventId] is the SSE `id` (message [ChatMessage.seq]).
class ChatStreamEvent extends Equatable {
  const ChatStreamEvent({
    required this.type,
    required this.message,
    this.eventId,
  });

  factory ChatStreamEvent.fromSse({
    required String eventName,
    required Object? data,
    String? eventId,
  }) {
    final Map<String, dynamic> map = Json.map(data);
    return ChatStreamEvent(
      type: ChatStreamEventTypeX.parse(eventName),
      message: ChatMessage.fromJson(map),
      eventId: eventId ?? Json.stringOrNull(map['seq']),
    );
  }

  final ChatStreamEventType type;
  final ChatMessage message;
  final String? eventId;

  @override
  List<Object?> get props => <Object?>[type, message, eventId];
}

extension ChatStreamEventTypeX on ChatStreamEventType {
  static ChatStreamEventType parse(String raw) {
    switch (raw) {
      case 'message':
        return ChatStreamEventType.message;
      case 'message_edited':
        return ChatStreamEventType.messageEdited;
      case 'message_deleted':
        return ChatStreamEventType.messageDeleted;
      default:
        return ChatStreamEventType.unknown;
    }
  }
}
