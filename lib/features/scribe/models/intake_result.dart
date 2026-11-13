import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

/// Result of `POST /patients/:id/intake` (audio or image → source + facts).
class IntakeResult extends Equatable {
  const IntakeResult({
    required this.sourceId,
    required this.text,
    this.factIds = const <String>[],
    this.lowLegibilityLines = const <String>[],
    this.confidence,
  });

  factory IntakeResult.fromJson(Map<String, dynamic> json) {
    return IntakeResult(
      sourceId: Json.firstString(json, const <String>['source_id', 'id']),
      text: Json.firstString(json, const <String>[
        'transcript_or_text',
        'text',
        'transcript',
      ]),
      factIds: Json.strings(json['fact_ids']),
      lowLegibilityLines: Json.strings(json['low_legibility_lines']),
      confidence: Json.stringOrNull(json['confidence']),
    );
  }

  final String sourceId;
  final String text;
  final List<String> factIds;
  final List<String> lowLegibilityLines;
  final String? confidence;

  int get pendingFactCount => factIds.length;

  @override
  List<Object?> get props => <Object?>[
    sourceId,
    text,
    factIds,
    lowLegibilityLines,
    confidence,
  ];
}

/// Result of `POST /transcribe` (audio → text only, no source).
class TranscribeResult extends Equatable {
  const TranscribeResult({required this.text, this.model});

  factory TranscribeResult.fromJson(Map<String, dynamic> json) {
    return TranscribeResult(
      text: Json.firstString(json, const <String>['text', 'transcript']),
      model: Json.stringOrNull(json['model']),
    );
  }

  final String text;
  final String? model;

  @override
  List<Object?> get props => <Object?>[text, model];
}
