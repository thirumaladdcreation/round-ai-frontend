import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/evidence/models/evidence_result.dart';

abstract class EvidenceRepository {
  /// Searches on one confirmed or differential problem, or on a typed topic.
  /// Exactly one of [problemId] and [topic] is given. Only the topic or the
  /// problem is sent. No patient text goes with it.
  Future<Result<EvidenceResult>> search(
    String patientId, {
    String? problemId,
    String? topic,
    required String idempotencyKey,
    CancelToken? cancelToken,
  });
}
