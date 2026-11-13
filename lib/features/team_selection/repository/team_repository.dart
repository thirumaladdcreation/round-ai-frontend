import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/team_selection/models/clinical_team.dart';

abstract class TeamRepository {
  String? get savedTeamId;

  Future<Result<List<ClinicalTeam>>> loadAuthorizedTeams();

  Future<Result<void>> saveSelectedTeam(String teamId);
}
