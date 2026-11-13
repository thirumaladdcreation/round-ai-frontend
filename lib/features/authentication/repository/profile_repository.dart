import 'package:flutter/foundation.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/authentication/models/app_user.dart';
import 'package:round_ai/features/team_selection/models/clinical_team.dart';

/// The signed-in clinician: name, role, teams and the AI switch.
/// It is loaded from `GET /me` and kept only in memory.
abstract class ProfileRepository {
  /// Null until [load] succeeds, and again after [clear].
  MeProfile? get current;

  /// Fires when [current] changes. The AI banner listens to this.
  ValueListenable<MeProfile?> get changes;

  Future<Result<MeProfile>> load();

  /// Called on sign-out.
  void clear();
}

extension ProfileLookup on ProfileRepository {
  /// The saved team, if it is one of the user's teams.
  ClinicalTeam? teamById(String? id) {
    final MeProfile? me = current;
    if (me == null || id == null) return null;
    for (final ClinicalTeam team in me.teams) {
      if (team.id == id) return team;
    }
    return null;
  }

  /// The signed-in user's name from `/me`, else [fallback].
  String nameOr(String fallback) {
    final String name = current?.user.name.trim() ?? '';
    return name.isEmpty ? fallback : name;
  }

  /// False only when the backend said AI is off. Unknown counts as on, so
  /// the banner does not flash before the profile arrives.
  bool get aiOff => current != null && !current!.aiEnabled;

  /// False only when `/me` said `chat_enabled` is false. Unknown counts as on
  /// so the Chat tab can load and show a calm banner if the API rejects.
  bool get chatOff => current != null && !current!.chatEnabled;
}
