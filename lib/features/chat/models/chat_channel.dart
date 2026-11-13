import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

enum ChatChannelType { team, group, dm, patient, unknown }

/// One channel from `GET /channels` / create / patient channel.
///
/// Backend sorts by `type`, then `name` — there is no `last_activity` field.
class ChatChannel extends Equatable {
  const ChatChannel({
    required this.id,
    required this.teamId,
    required this.name,
    required this.type,
    required this.archived,
    required this.unread,
    this.patientId,
    this.createdAt,
  });

  factory ChatChannel.fromJson(Map<String, dynamic> json) {
    return ChatChannel(
      id: Json.string(json['id']),
      teamId: Json.string(json['team_id']),
      name: Json.string(json['name']),
      type: ChatChannelTypeX.parse(Json.string(json['type'])),
      patientId: Json.stringOrNull(json['patient_id']),
      archived: Json.boolean(json['archived']),
      unread: Json.integer(json['unread']),
      createdAt: Json.date(json['created_at']),
    );
  }

  final String id;
  final String teamId;
  final String name;
  final ChatChannelType type;
  final String? patientId;
  final bool archived;
  final int unread;
  final DateTime? createdAt;

  bool get isPatientThread => type == ChatChannelType.patient;

  ChatChannel copyWith({int? unread, bool? archived}) {
    return ChatChannel(
      id: id,
      teamId: teamId,
      name: name,
      type: type,
      patientId: patientId,
      archived: archived ?? this.archived,
      unread: unread ?? this.unread,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    teamId,
    name,
    type,
    patientId,
    archived,
    unread,
    createdAt,
  ];
}

extension ChatChannelTypeX on ChatChannelType {
  static ChatChannelType parse(String raw) {
    switch (raw.toLowerCase()) {
      case 'team':
        return ChatChannelType.team;
      case 'group':
        return ChatChannelType.group;
      case 'dm':
        return ChatChannelType.dm;
      case 'patient':
        return ChatChannelType.patient;
      default:
        return ChatChannelType.unknown;
    }
  }

  String get apiValue {
    switch (this) {
      case ChatChannelType.team:
        return 'team';
      case ChatChannelType.group:
        return 'group';
      case ChatChannelType.dm:
        return 'dm';
      case ChatChannelType.patient:
        return 'patient';
      case ChatChannelType.unknown:
        return 'unknown';
    }
  }
}
