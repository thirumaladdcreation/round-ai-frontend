import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';

abstract class HomeRepository {
  Future<Result<HomeSnapshot>> load();
}
