import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/features/authentication/models/app_user.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/splash/repository/splash_repository.dart';
import 'package:round_ai/features/team_selection/models/clinical_team.dart';

/// Chooses the first screen from the saved token and `GET /me`.
class SplashRepositoryImpl implements SplashRepository {
  const SplashRepositoryImpl(this._storage, this._profile);

  final AppStorage _storage;
  final ProfileRepository _profile;

  @override
  Future<Result<String>> destination() async {
    if (!_storage.hasAuthToken) return const Ok<String>(AppRoutes.signIn);

    final Result<MeProfile> result = await _profile.load();
    switch (result) {
      case Err<MeProfile>(:final failure):
        // A rejected token was already cleared by the 401 handler.
        if (failure is ApiFailure && failure.error.isUnauthenticated) {
          return const Ok<String>(AppRoutes.signIn);
        }
        return Err<String>(failure);
      case Ok<MeProfile>(:final value):
        return Ok<String>(await _afterProfile(value.teams));
    }
  }

  Future<String> _afterProfile(List<ClinicalTeam> teams) async {
    if (teams.isEmpty) return AppRoutes.selectTeam;
    final String? saved = _storage.selectedTeamId;
    if (teams.any((ClinicalTeam t) => t.id == saved)) return AppRoutes.today;
    if (teams.length == 1) {
      await _storage.saveSelectedTeam(teams.first.id);
      return AppRoutes.today;
    }
    return AppRoutes.selectTeam;
  }
}
