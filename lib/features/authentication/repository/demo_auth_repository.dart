import 'package:round_ai/core/constants/app_constants.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/features/authentication/repository/auth_repository.dart';

/// Local session for `--dart-define=USE_DEMO=true`. Nothing leaves the device.
/// The password is checked in memory and is never stored.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository(this._storage);

  final AppStorage _storage;

  @override
  Future<Result<void>> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final String trimmedEmail = email.trim();
    if (!_looksLikeEmail(trimmedEmail)) {
      return const Err<void>(ValidationFailure('Enter a valid email address.'));
    }
    if (password.trim().length < 6) {
      return const Err<void>(
        ValidationFailure('Password must be at least 6 characters.'),
      );
    }

    await _storage.saveRememberMe(enabled: rememberMe, email: trimmedEmail);
    await _storage.session.save('local-demo-session', persist: rememberMe);
    await _storage.saveString(AppConstants.clinicianNameKey, 'Dr. Rivera');
    return const Ok<void>(null);
  }

  bool _looksLikeEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }
}
