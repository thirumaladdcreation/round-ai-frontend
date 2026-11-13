import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';

/// `GET /channels/unread`.
class UnreadSummary extends Equatable {
  const UnreadSummary({
    required this.totalUnread,
    required this.channels,
  });

  factory UnreadSummary.fromJson(Map<String, dynamic> json) {
    return UnreadSummary(
      totalUnread: Json.integer(json['total_unread']),
      channels: Json.itemsOf(json, 'channels')
          .map(UnreadChannel.fromJson)
          .where((UnreadChannel c) => c.id.isNotEmpty)
          .toList(),
    );
  }

  final int totalUnread;
  final List<UnreadChannel> channels;

  @override
  List<Object> get props => <Object>[totalUnread, channels];
}

class UnreadChannel extends Equatable {
  const UnreadChannel({
    required this.id,
    required this.unread,
    required this.type,
    this.patientId,
  });

  factory UnreadChannel.fromJson(Map<String, dynamic> json) {
    return UnreadChannel(
      id: Json.string(json['id']),
      unread: Json.integer(json['unread']),
      type: ChatChannelTypeX.parse(Json.string(json['type'])),
      patientId: Json.stringOrNull(json['patient_id']),
    );
  }

  final String id;
  final int unread;
  final ChatChannelType type;
  final String? patientId;

  @override
  List<Object?> get props => <Object?>[id, unread, type, patientId];
}

/// `POST /channels/:id/read` response.
class ChannelReadResult extends Equatable {
  const ChannelReadResult({
    required this.channelId,
    required this.lastReadSeq,
    required this.unread,
  });

  factory ChannelReadResult.fromJson(Map<String, dynamic> json) {
    return ChannelReadResult(
      channelId: Json.string(json['channel_id']),
      lastReadSeq: Json.integer(json['last_read_seq']),
      unread: Json.integer(json['unread']),
    );
  }

  final String channelId;
  final int lastReadSeq;
  final int unread;

  @override
  List<Object> get props => <Object>[channelId, lastReadSeq, unread];
}
