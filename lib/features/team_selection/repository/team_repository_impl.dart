import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/features/authentication/models/app_user.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/team_selection/models/clinical_team.dart';
import 'package:round_ai/features/team_selection/repository/team_repository.dart';

/// Teams come from `GET /me`, so only teams the user may open are listed.
class TeamRepositoryImpl implements TeamRepository {
  TeamRepositoryImpl(this._profile, this._storage);

  final ProfileRepository _profile;
  final AppStorage _storage;

  @override
  String? get savedTeamId => _storage.selectedTeamId;

  @override
  Future<Result<List<ClinicalTeam>>> loadAuthorizedTeams() async {
    // Refresh, so a team added on the server shows up when switching.
    final Result<MeProfile> result = await _profile.load();
    switch (result) {
      case Ok<MeProfile>(:final value):
        return Ok<List<ClinicalTeam>>(value.teams);
      case Err<MeProfile>(:final failure):
        return Err<List<ClinicalTeam>>(failure);
    }
  }

  @override
  Future<Result<void>> saveSelectedTeam(String teamId) async {
    final List<ClinicalTeam>? known = _profile.current?.teams;
    if (known != null && !known.any((ClinicalTeam t) => t.id == teamId)) {
      return const Err<void>(
        ValidationFailure('That team is not assigned to you.'),
      );
    }
    await _storage.saveSelectedTeam(teamId);
    return const Ok<void>(null);
  }
}
