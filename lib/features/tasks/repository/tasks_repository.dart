import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/tasks/models/patient_task.dart';

abstract class TasksRepository {
  /// Every task of one patient: proposed, open, completed and dismissed.
  Future<Result<List<PatientTask>>> list(String patientId);

  /// Suggests tasks from the saved plan. They come back as proposed and are
  /// not tasks until the clinician accepts them.
  Future<Result<List<PatientTask>>> propose(
    String patientId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  /// A task the clinician types. Owner and due time are optional. A blank
  /// one stays unassigned.
  Future<Result<void>> add(
    String patientId, {
    required String title,
    String? owner,
    DateTime? dueAt,
  });

  Future<Result<void>> accept(String taskId, {String? owner, DateTime? dueAt});

  Future<Result<void>> dismiss(String taskId);

  Future<Result<void>> complete(String taskId);
}
