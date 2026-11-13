import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/tasks/models/patient_task.dart';
import 'package:round_ai/features/tasks/repository/tasks_repository.dart';

/// Demo builds keep their screens on the in-memory task board. This answers
/// honestly if something asks for real tasks.
class DemoTasksRepository implements TasksRepository {
  static Failure get _off => ApiFailure(
    const ApiError(code: 'ai_disabled', message: 'Demo build', status: 503),
  );

  @override
  Future<Result<List<PatientTask>>> list(String patientId) async =>
      const Ok<List<PatientTask>>(<PatientTask>[]);

  @override
  Future<Result<List<PatientTask>>> propose(
    String patientId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async => Err<List<PatientTask>>(_off);

  @override
  Future<Result<void>> add(
    String patientId, {
    required String title,
    String? owner,
    DateTime? dueAt,
  }) async => Err<void>(_off);

  @override
  Future<Result<void>> accept(
    String taskId, {
    String? owner,
    DateTime? dueAt,
  }) async => Err<void>(_off);

  @override
  Future<Result<void>> dismiss(String taskId) async => Err<void>(_off);

  @override
  Future<Result<void>> complete(String taskId) async => Err<void>(_off);
}
