import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

/// Server message body max (`CHAT_MAX_BODY`). Enforce in the composer too.
const int kChatMaxBodyLength = 4000;

/// One message from list/post/edit/delete/search/stream payloads.
///
/// Soft-deleted messages keep [id]/[seq] with empty [body] and [deleted]=true.
/// There is no `client_message_id` / reply_count on the wire.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.body,
    required this.seq,
    required this.deleted,
    this.parentId,
    this.editedAt,
    this.deletedAt,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final bool deleted = Json.boolean(json['deleted']);
    return ChatMessage(
      id: Json.string(json['id']),
      channelId: Json.string(json['channel_id']),
      senderId: Json.string(json['sender_id']),
      // Deleted payloads must never surface prior text in the UI layer.
      body: deleted ? '' : Json.string(json['body']),
      seq: Json.integer(json['seq']),
      parentId: Json.stringOrNull(json['parent_id']),
      deleted: deleted,
      editedAt: Json.date(json['edited_at']),
      deletedAt: Json.date(json['deleted_at']),
      createdAt: Json.date(json['created_at']),
    );
  }

  final String id;
  final String channelId;
  final String senderId;
  final String body;
  final int seq;
  final String? parentId;
  final bool deleted;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  bool get isEdited => editedAt != null && !deleted;
  bool get isThreadReply => parentId != null && parentId!.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[
    id,
    channelId,
    senderId,
    body,
    seq,
    parentId,
    deleted,
    editedAt,
    deletedAt,
    createdAt,
  ];
}
