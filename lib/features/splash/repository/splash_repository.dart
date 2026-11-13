import 'package:round_ai/core/errors/result.dart';

abstract class SplashRepository {
  /// Next route from the saved session.
  ///
  /// With a saved token this asks the backend (`GET /me`) whether the token
  /// still works. An [Err] means the answer is unknown, for example offline.
  /// A rejected token is not an error: it gives the sign-in route.
  Future<Result<String>> destination();
}
