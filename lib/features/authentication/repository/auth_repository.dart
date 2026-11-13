import 'package:round_ai/core/errors/result.dart';

abstract class AuthRepository {
  Future<Result<void>> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  });
}
