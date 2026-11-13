import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/features/team_selection/models/clinical_team.dart';
import 'package:round_ai/features/team_selection/repository/team_repository.dart';

class DemoTeamRepository implements TeamRepository {
  DemoTeamRepository(this._storage);

  final AppStorage _storage;

  @override
  String? get savedTeamId => _storage.selectedTeamId;

  @override
  Future<Result<List<ClinicalTeam>>> loadAuthorizedTeams() async {
    return const Ok<List<ClinicalTeam>>(demoTeams);
  }

  @override
  Future<Result<void>> saveSelectedTeam(String teamId) async {
    final bool allowed = demoTeams.any(
      (ClinicalTeam team) => team.id == teamId,
    );
    if (!allowed) {
      return const Err<void>(
        ValidationFailure('That team is not assigned to you.'),
      );
    }
    await _storage.saveSelectedTeam(teamId);
    return const Ok<void>(null);
  }
}
