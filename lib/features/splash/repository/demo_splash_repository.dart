import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/features/splash/repository/splash_repository.dart';

/// Local routing for `USE_DEMO=true`. No network.
class DemoSplashRepository implements SplashRepository {
  const DemoSplashRepository(this._storage);

  final AppStorage _storage;

  @override
  Future<Result<String>> destination() async {
    if (!_storage.hasAuthToken) return const Ok<String>(AppRoutes.signIn);
    if (!_storage.hasSelectedTeam) {
      return const Ok<String>(AppRoutes.selectTeam);
    }
    return const Ok<String>(AppRoutes.census);
  }
}
