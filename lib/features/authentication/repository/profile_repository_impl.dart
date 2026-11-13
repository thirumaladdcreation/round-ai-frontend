import 'package:flutter/foundation.dart';
import 'package:round_ai/core/constants/app_constants.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/authentication/models/app_user.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._client, this._storage);

  final ApiClient _client;
  final AppStorage _storage;
  final ValueNotifier<MeProfile?> _profile = ValueNotifier<MeProfile?>(null);

  @override
  MeProfile? get current => _profile.value;

  @override
  ValueListenable<MeProfile?> get changes => _profile;

  @override
  Future<Result<MeProfile>> load() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(ApiEndpoints.me);
      final MeProfile me = MeProfile.fromJson(Json.map(response.data));
      if (me.user.name.isNotEmpty) {
        await _storage.saveString(AppConstants.clinicianNameKey, me.user.name);
      }
      _profile.value = me;
      return Ok<MeProfile>(me);
    } on ApiError catch (error) {
      return Err<MeProfile>(ApiFailure(error));
    }
  }

  @override
  void clear() => _profile.value = null;
}
