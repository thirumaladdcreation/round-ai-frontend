import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/rounds/models/prepare_result.dart';
import 'package:round_ai/features/rounds/models/presentation_draft.dart';
import 'package:round_ai/features/rounds/models/round_brief.dart';
import 'package:round_ai/features/rounds/models/round_reminder.dart';

abstract class RoundRepository {
  Future<Result<RoundBrief>> loadBrief({String? date, String? teamId});

  Future<Result<PreparePresentationsResult>> preparePresentations({
    required List<String> patientIds,
    required String idempotencyKey,
    String? date,
    CancelToken? cancelToken,
  });

  Future<Result<PresentationResult>> present(
    String patientId, {
    required String idempotencyKey,
    String? date,
    CancelToken? cancelToken,
  });

  Future<Result<ReminderListResult>> loadReminders(
    String patientId, {
    String? date,
  });

  Future<Result<ReminderAck>> ackReminder(
    String patientId,
    String ruleId, {
    required ReminderAckState state,
    String? note,
    String? date,
  });
}
