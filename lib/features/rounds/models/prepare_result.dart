import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

class PreparePatientResult extends Equatable {
  const PreparePatientResult({
    required this.patientId,
    required this.ok,
    this.artifactId,
    this.status,
    this.wordCount,
    this.requiresReview = true,
    this.errorCode,
    this.errorMessage,
  });

  factory PreparePatientResult.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> error = Json.map(json['error']);
    return PreparePatientResult(
      patientId: Json.string(json['patient_id']),
      ok: Json.boolean(json['ok']),
      artifactId: Json.stringOrNull(json['artifact_id']),
      status: Json.stringOrNull(json['status']),
      wordCount: Json.integerOrNull(json['word_count']),
      requiresReview: Json.boolean(json['requires_review'], true),
      errorCode: Json.stringOrNull(error['code']),
      errorMessage: Json.stringOrNull(error['message']),
    );
  }

  final String patientId;
  final bool ok;
  final String? artifactId;
  final String? status;
  final int? wordCount;
  final bool requiresReview;
  final String? errorCode;
  final String? errorMessage;

  bool get isDailyLimit => errorCode == 'daily_limit';

  String get failureReason {
    if (ok) return '';
    if (isDailyLimit) {
      return 'Daily AI usage limit reached. Presentation not generated.';
    }
    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return errorMessage!;
    }
    return errorCode ?? 'Presentation generation failed';
  }

  @override
  List<Object?> get props => <Object?>[patientId, ok, errorCode];
}

class PreparePresentationsResult extends Equatable {
  const PreparePresentationsResult({
    required this.date,
    required this.requested,
    required this.generated,
    required this.failed,
    required this.results,
    this.dailyCap = 0,
    this.callsRemainingBefore = 0,
    this.note = '',
  });

  factory PreparePresentationsResult.fromJson(Map<String, dynamic> json) {
    return PreparePresentationsResult(
      date: Json.string(json['date']),
      requested: Json.integer(json['requested']),
      generated: Json.integer(json['generated']),
      failed: Json.integer(json['failed']),
      dailyCap: Json.integer(json['daily_cap']),
      callsRemainingBefore: Json.integer(json['calls_remaining_before']),
      results: Json.maps(
        json['results'],
      ).map(PreparePatientResult.fromJson).toList(),
      note: Json.string(json['note']),
    );
  }

  final String date;
  final int requested;
  final int generated;
  final int failed;
  final int dailyCap;
  final int callsRemainingBefore;
  final List<PreparePatientResult> results;
  final String note;

  bool get hasFailures => failed > 0 || results.any((PreparePatientResult r) => !r.ok);

  @override
  List<Object?> get props => <Object?>[date, requested, generated, failed, results];
}
