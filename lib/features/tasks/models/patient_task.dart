import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

/// A proposed task is not a task until the clinician accepts it.
enum TaskStatus { proposed, open, completed, dismissed }

class PatientTask extends Equatable {
  const PatientTask({
    required this.id,
    required this.patientId,
    required this.title,
    required this.status,
    this.owner,
    this.dueAt,
  });

  factory PatientTask.fromJson(Map<String, dynamic> json) {
    return PatientTask(
      id: Json.string(json['id']),
      patientId: Json.string(json['patient_id']),
      // Backend field is `text`; older clients used `title`.
      title: Json.firstString(json, <String>['text', 'title']),
      status: switch (Json.firstString(json, <String>[
        'state',
        'status',
      ]).toLowerCase()) {
        'open' || 'accepted' => TaskStatus.open,
        'completed' || 'done' => TaskStatus.completed,
        'dismissed' => TaskStatus.dismissed,
        _ => TaskStatus.proposed,
      },
      // Not stated means Unassigned / Not entered. Never filled in.
      owner: Json.stringOrNull(json['owner']),
      dueAt: Json.date(json['due'] ?? json['due_at']),
    );
  }

  final String id;
  final String patientId;
  final String title;
  final TaskStatus status;
  final String? owner;
  final DateTime? dueAt;

  /// Past its due time and still open. Worked out from the clock, never by AI.
  bool isOverdue(DateTime now) =>
      status == TaskStatus.open && dueAt != null && dueAt!.isBefore(now);

  @override
  List<Object?> get props => <Object?>[
    id,
    patientId,
    title,
    status,
    owner,
    dueAt,
  ];
}
