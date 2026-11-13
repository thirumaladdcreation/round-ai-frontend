import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

/// What kind of text a source is. The wire value is sent as `kind`.
enum ChartSourceKind {
  progressNote('progress_note', 'Progress note'),
  labs('labs', 'Labs'),
  imaging('imaging', 'Imaging'),
  nursing('nursing', 'Nursing'),
  consult('consult', 'Consult'),
  dictation('dictation', 'Dictation'),
  imageExtract('image_extract', 'Image extract'),
  other('other', 'Other');

  const ChartSourceKind(this.wire, this.label);

  final String wire;
  final String label;

  /// Intake media that can feed note fields via `inputs_from_source_ids`.
  bool get feedsNotes =>
      this == ChartSourceKind.dictation || this == ChartSourceKind.imageExtract;

  static ChartSourceKind parse(Object? value) {
    final String text = Json.string(value).toLowerCase();
    for (final ChartSourceKind kind in ChartSourceKind.values) {
      if (kind.wire == text) return kind;
    }
    return ChartSourceKind.other;
  }
}

/// A piece of chart text the clinician pasted in. Facts are extracted from it
/// and stay pending until a clinician confirms them.
class ChartSource extends Equatable {
  const ChartSource({
    required this.id,
    required this.kind,
    this.time,
    this.title,
  });

  factory ChartSource.fromJson(Map<String, dynamic> json) {
    return ChartSource(
      id: Json.string(json['id']),
      kind: ChartSourceKind.parse(json['kind']),
      // A missing time stays null and is shown as Unknown.
      time: Json.date(
        json['event_time'] ?? json['time'] ?? json['source_time'],
      ),
      title: Json.stringOrNull(json['title']),
    );
  }

  final String id;
  final ChartSourceKind kind;
  final DateTime? time;
  final String? title;

  @override
  List<Object?> get props => <Object?>[id, kind, time, title];
}
