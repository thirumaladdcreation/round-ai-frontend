import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/problems/models/coding_suggestion.dart';

/// A suggested problem is never shown as confirmed.
enum ProblemState {
  documented('Documented in source'),
  suggested('Suggested by AI'),
  confirmed('Confirmed'),
  differential('Differential'),
  rejected('Rejected'),
  resolved('Resolved');

  const ProblemState(this.label);

  final String label;

  static ProblemState parse(Object? value) {
    switch (Json.string(value).toLowerCase()) {
      case 'documented':
      case 'documented_in_source':
        return ProblemState.documented;
      case 'confirmed':
      case 'clinician_confirmed':
        return ProblemState.confirmed;
      case 'differential':
        return ProblemState.differential;
      case 'rejected':
      case 'clinician_rejected':
        return ProblemState.rejected;
      case 'resolved':
        return ProblemState.resolved;
    }
    // Anything unknown is treated as a suggestion, never as confirmed.
    return ProblemState.suggested;
  }

  /// ICD suggest/accept only for confirmed or differential.
  bool get canSuggestCodes =>
      this == ProblemState.confirmed || this == ProblemState.differential;
}

class Problem extends Equatable {
  const Problem({
    required this.id,
    required this.label,
    required this.state,
    this.factIds = const <String>[],
    this.uncertainty,
    this.codeSuggestion,
  });

  factory Problem.fromJson(Map<String, dynamic> json) {
    final Object? rawCode = json['code_suggestion'];
    return Problem(
      id: Json.string(json['id']),
      label: Json.string(json['label'] ?? json['name']),
      state: ProblemState.parse(json['state']),
      factIds: Json.strings(json['fact_ids']),
      uncertainty: Json.stringOrNull(json['uncertainty']),
      codeSuggestion: rawCode == null || (rawCode is Map && rawCode.isEmpty)
          ? null
          : AcceptedCodeSuggestion.fromJson(rawCode),
    );
  }

  final String id;
  final String label;
  final ProblemState state;
  final List<String> factIds;
  final String? uncertainty;
  final AcceptedCodeSuggestion? codeSuggestion;

  Problem copyWith({
    ProblemState? state,
    List<String>? factIds,
    String? uncertainty,
    AcceptedCodeSuggestion? codeSuggestion,
    bool clearCodeSuggestion = false,
  }) {
    return Problem(
      id: id,
      label: label,
      state: state ?? this.state,
      factIds: factIds ?? this.factIds,
      uncertainty: uncertainty ?? this.uncertainty,
      codeSuggestion: clearCodeSuggestion
          ? null
          : (codeSuggestion ?? this.codeSuggestion),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    label,
    state,
    factIds,
    uncertainty,
    codeSuggestion,
  ];
}
