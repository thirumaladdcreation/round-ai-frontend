import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

/// One row from `POST /census/intake` — proposed only until confirm.
class ProposedCensusPatient extends Equatable {
  const ProposedCensusPatient({
    required this.index,
    required this.displayName,
    this.room = '',
    this.ageBand = '',
    this.sex = '',
    this.oneLineReason = '',
    this.sourceText = '',
    this.skipped = false,
  });

  factory ProposedCensusPatient.fromJson(Map<String, dynamic> json) {
    return ProposedCensusPatient(
      index: Json.integer(json['index']),
      displayName: Json.string(json['display_name']),
      room: Json.string(json['room']),
      ageBand: Json.string(json['age_band']),
      sex: Json.string(json['sex']),
      oneLineReason: Json.string(json['one_line_reason']),
      sourceText: Json.string(json['source_text']),
    );
  }

  final int index;
  final String displayName;
  final String room;
  final String ageBand;
  final String sex;
  final String oneLineReason;
  final String sourceText;
  final bool skipped;

  ProposedCensusPatient copyWith({
    String? displayName,
    String? room,
    String? ageBand,
    String? sex,
    String? oneLineReason,
    String? sourceText,
    bool? skipped,
  }) {
    return ProposedCensusPatient(
      index: index,
      displayName: displayName ?? this.displayName,
      room: room ?? this.room,
      ageBand: ageBand ?? this.ageBand,
      sex: sex ?? this.sex,
      oneLineReason: oneLineReason ?? this.oneLineReason,
      sourceText: sourceText ?? this.sourceText,
      skipped: skipped ?? this.skipped,
    );
  }

  /// One confirm payload item for this row.
  Map<String, Object> toConfirmItem() {
    if (skipped) {
      return <String, Object>{'index': index, 'skip': true};
    }
    return <String, Object>{
      'index': index,
      'edits': <String, String>{
        'display_name': displayName,
        'room': room,
        'age_band': ageBand,
        'sex': sex,
        'one_line_reason': oneLineReason,
        'source_text': sourceText,
      },
    };
  }

  @override
  List<Object?> get props => <Object?>[
    index,
    displayName,
    room,
    ageBand,
    sex,
    oneLineReason,
    sourceText,
    skipped,
  ];
}

/// Result of `POST /census/intake`.
class CensusIntakeProposal extends Equatable {
  const CensusIntakeProposal({
    required this.id,
    required this.patients,
    this.sourceText = '',
    this.note = '',
    this.lowLegibilityLines = const <String>[],
    this.confidence,
  });

  factory CensusIntakeProposal.fromJson(Map<String, dynamic> json) {
    final Object? raw = json['patients'];
    final List<ProposedCensusPatient> patients = <ProposedCensusPatient>[];
    if (raw is List) {
      for (int i = 0; i < raw.length; i++) {
        final Map<String, dynamic> map = Json.map(raw[i]);
        if (!map.containsKey('index')) map['index'] = i;
        patients.add(ProposedCensusPatient.fromJson(map));
      }
    }
    return CensusIntakeProposal(
      id: Json.firstString(json, const <String>['id', 'intake_id']),
      patients: patients,
      sourceText: Json.string(json['source_text']),
      note: Json.string(json['note']),
      lowLegibilityLines: Json.strings(json['low_legibility_lines']),
      confidence: Json.stringOrNull(json['confidence']),
    );
  }

  final String id;
  final List<ProposedCensusPatient> patients;
  final String sourceText;
  final String note;
  final List<String> lowLegibilityLines;
  final String? confidence;

  @override
  List<Object?> get props => <Object?>[
    id,
    patients,
    sourceText,
    note,
    lowLegibilityLines,
    confidence,
  ];
}

/// One patient created by confirm.
class CensusCreatedPatient extends Equatable {
  const CensusCreatedPatient({
    required this.patientId,
    required this.index,
    this.factId,
  });

  factory CensusCreatedPatient.fromJson(Map<String, dynamic> json) {
    return CensusCreatedPatient(
      patientId: Json.firstString(json, const <String>['patient_id', 'id']),
      index: Json.integer(json['index']),
      factId: Json.stringOrNull(json['fact_id']),
    );
  }

  final String patientId;
  final int index;
  final String? factId;

  @override
  List<Object?> get props => <Object?>[patientId, index, factId];
}

/// Result of `POST /census/intake/:id/confirm`.
class CensusConfirmResult extends Equatable {
  const CensusConfirmResult({
    required this.intakeId,
    required this.created,
  });

  factory CensusConfirmResult.fromJson(Map<String, dynamic> json) {
    final Object? raw = json['created'];
    final List<CensusCreatedPatient> created = <CensusCreatedPatient>[];
    if (raw is List) {
      for (final Object item in raw) {
        created.add(CensusCreatedPatient.fromJson(Json.map(item)));
      }
    }
    return CensusConfirmResult(
      intakeId: Json.firstString(json, const <String>['intake_id', 'id']),
      created: created,
    );
  }

  final String intakeId;
  final List<CensusCreatedPatient> created;

  /// First created patient that has a pending admission-reason fact.
  String? get firstFactsPatientId {
    for (final CensusCreatedPatient c in created) {
      if (c.factId != null && c.factId!.isNotEmpty) return c.patientId;
    }
    return created.isEmpty ? null : created.first.patientId;
  }

  @override
  List<Object?> get props => <Object?>[intakeId, created];
}

/// Result of `GET /census/export`.
class CensusExport extends Equatable {
  const CensusExport({
    required this.text,
    this.note = '',
    this.orderedBy = '',
    this.patientCount = 0,
  });

  factory CensusExport.fromJson(Map<String, dynamic> json) {
    final Object? patients = json['patients'];
    return CensusExport(
      text: Json.string(json['text']),
      note: Json.string(json['note']),
      orderedBy: Json.string(json['ordered_by']),
      patientCount: patients is List ? patients.length : 0,
    );
  }

  final String text;
  final String note;
  final String orderedBy;
  final int patientCount;

  @override
  List<Object?> get props => <Object?>[text, note, orderedBy, patientCount];
}
