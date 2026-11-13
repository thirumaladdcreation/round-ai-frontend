import 'package:equatable/equatable.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';

/// A row in the channel timeline. Pending/failed are local-only optimistic rows.
enum ChatSendStatus { synced, pending, failed }

class ChatTimelineItem extends Equatable {
  const ChatTimelineItem({
    required this.message,
    this.status = ChatSendStatus.synced,
  });

  final ChatMessage message;
  final ChatSendStatus status;

  bool get isLocal =>
      status != ChatSendStatus.synced || message.id.startsWith('local:');

  ChatTimelineItem copyWith({
    ChatMessage? message,
    ChatSendStatus? status,
  }) {
    return ChatTimelineItem(
      message: message ?? this.message,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => <Object?>[message, status];
}
