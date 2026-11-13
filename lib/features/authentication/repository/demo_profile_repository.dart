import 'package:flutter/foundation.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/features/authentication/models/app_user.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/team_selection/models/clinical_team.dart';

/// Demo profile for `USE_DEMO=true`. No network. Always available, with AI on.
class DemoProfileRepository implements ProfileRepository {
  DemoProfileRepository(this._storage);

  final AppStorage _storage;
  late final ValueNotifier<MeProfile?> _profile = ValueNotifier<MeProfile?>(
    _build(),
  );

  MeProfile _build() {
    return MeProfile(
      user: AppUser(
        id: 'demo',
        name: _storage.clinicianName,
        email: _storage.rememberedEmail ?? '',
        role: 'Resident',
      ),
      teams: demoTeams,
      aiEnabled: true,
      chatEnabled: true,
    );
  }

  @override
  MeProfile? get current => _build();

  @override
  ValueListenable<MeProfile?> get changes => _profile;

  @override
  Future<Result<MeProfile>> load() async => Ok<MeProfile>(_build());

  @override
  void clear() {}
}
