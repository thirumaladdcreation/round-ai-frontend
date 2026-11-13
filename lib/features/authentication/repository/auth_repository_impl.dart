import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/authentication/models/app_user.dart';
import 'package:round_ai/features/authentication/repository/auth_repository.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';

/// Signs in against the backend: `POST /auth/login`, then `GET /me`.
/// The password is sent once and never stored. The token goes to secure
/// storage only when Remember me is on.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client, this._storage, this._profile);

  final ApiClient _client;
  final AppStorage _storage;
  final ProfileRepository _profile;

  @override
  Future<Result<void>> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final String trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      return const Err<void>(
        ValidationFailure('Enter your email and password.'),
      );
    }
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        data: <String, String>{'email': trimmedEmail, 'password': password},
      );
      final String token = Json.string(Json.map(response.data)['token']);
      if (token.isEmpty) {
        return Err<void>(
          ApiFailure(const ApiError(code: 'unknown_error', message: '')),
        );
      }
      await _storage.session.save(token, persist: rememberMe);
    } on ApiError catch (error) {
      return Err<void>(ApiFailure(error));
    }

    // The token only counts once /me accepts it.
    final Result<MeProfile> me = await _profile.load();
    if (me case Err<MeProfile>(:final failure)) {
      await _storage.clearAuthSession();
      return Err<void>(failure);
    }
    await _storage.saveRememberMe(enabled: rememberMe, email: trimmedEmail);
    return const Ok<void>(null);
  }
}
