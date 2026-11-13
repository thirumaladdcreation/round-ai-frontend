import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/team_selection/models/clinical_team.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: Json.string(json['id']),
      name: Json.string(json['name'] ?? json['display_name']),
      email: Json.string(json['email']),
      role: Json.string(json['role']),
    );
  }

  final String id;
  final String name;
  final String email;
  final String role;

  @override
  List<Object> get props => <Object>[id, name, email, role];
}

/// `GET /me`: the user, the teams they may open, and whether AI / chat are on.
class MeProfile extends Equatable {
  const MeProfile({
    required this.user,
    required this.teams,
    required this.aiEnabled,
    this.chatEnabled = false,
  });

  factory MeProfile.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> userJson = json['user'] is Map
        ? Json.map(json['user'])
        : json;
    final List<Map<String, dynamic>> rawTeams = Json.maps(json['teams']);
    return MeProfile(
      user: AppUser.fromJson(userJson),
      teams: <ClinicalTeam>[
        for (int i = 0; i < rawTeams.length; i++)
          ClinicalTeam.fromJson(rawTeams[i], index: i),
      ],
      // If the flag is missing, AI stays off.
      aiEnabled: Json.boolean(json['ai_enabled']),
      // Admin `chat_enabled`; missing means chat is off for the client.
      chatEnabled: Json.boolean(json['chat_enabled']),
    );
  }

  final AppUser user;
  final List<ClinicalTeam> teams;
  final bool aiEnabled;
  final bool chatEnabled;

  @override
  List<Object> get props => <Object>[user, teams, aiEnabled, chatEnabled];
}
