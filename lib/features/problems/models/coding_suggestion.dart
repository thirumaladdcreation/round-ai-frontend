import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

/// Required label on every ICD suggestion (rule 8).
const String codingReviewLabel =
    'Suggestion for clinician/coder review. Not a billing determination.';

/// One ICD candidate/suggestion from `suggest_icd`.
class IcdCodeSuggestion extends Equatable {
  const IcdCodeSuggestion({
    required this.code,
    required this.description,
    this.billable = false,
    this.factIds = const <String>[],
    this.missingForSpecificity = const <String>[],
    this.rationale = '',
    this.codingStatus = 'suggested',
  });

  factory IcdCodeSuggestion.fromJson(Map<String, dynamic> json) {
    return IcdCodeSuggestion(
      code: Json.string(json['code']).toUpperCase(),
      description: Json.string(json['description']),
      billable: Json.boolean(json['billable']),
      factIds: Json.strings(json['fact_ids']),
      missingForSpecificity: Json.strings(json['missing_for_specificity']),
      rationale: Json.string(json['rationale']),
      codingStatus: Json.string(json['coding_status'], 'suggested'),
    );
  }

  final String code;
  final String description;
  final bool billable;
  final List<String> factIds;
  final List<String> missingForSpecificity;
  final String rationale;
  final String codingStatus;

  bool get uncertainNotConfirmed =>
      codingStatus == 'uncertain_not_confirmed';

  @override
  List<Object?> get props => <Object?>[
    code,
    description,
    billable,
    factIds,
    missingForSpecificity,
    rationale,
    codingStatus,
  ];
}

/// Per-problem block inside a coding suggest artifact.
class CodingProblemBlock extends Equatable {
  const CodingProblemBlock({
    required this.problemId,
    required this.problemLabel,
    this.problemState,
    this.uncertain = false,
    this.suggestions = const <IcdCodeSuggestion>[],
    this.candidates = const <IcdCodeSuggestion>[],
    this.reviewerNotes = const <String>[],
    this.label = codingReviewLabel,
  });

  factory CodingProblemBlock.fromJson(Map<String, dynamic> json) {
    List<IcdCodeSuggestion> parseList(Object? raw) {
      if (raw is! List) return const <IcdCodeSuggestion>[];
      return raw
          .map((Object? e) => IcdCodeSuggestion.fromJson(Json.map(e)))
          .where((IcdCodeSuggestion s) => s.code.isNotEmpty)
          .toList();
    }

    return CodingProblemBlock(
      problemId: Json.firstString(json, const <String>[
        'problem_id',
        'id',
      ]),
      problemLabel: Json.firstString(json, const <String>[
        'problem_label',
        'label',
      ]),
      problemState: Json.stringOrNull(json['problem_state']),
      uncertain: Json.boolean(json['uncertain']),
      suggestions: parseList(json['suggestions']),
      candidates: parseList(json['candidates']),
      reviewerNotes: Json.strings(json['reviewer_notes']),
      label: Json.string(json['label'], codingReviewLabel),
    );
  }

  final String problemId;
  final String problemLabel;
  final String? problemState;
  final bool uncertain;
  final List<IcdCodeSuggestion> suggestions;
  final List<IcdCodeSuggestion> candidates;
  final List<String> reviewerNotes;
  final String label;

  bool get hasNoCandidates =>
      suggestions.isEmpty && candidates.isEmpty;

  @override
  List<Object?> get props => <Object?>[
    problemId,
    problemLabel,
    problemState,
    uncertain,
    suggestions,
    candidates,
    reviewerNotes,
    label,
  ];
}

/// Result of `POST /patients/:id/coding/suggest`.
class CodingSuggestResult extends Equatable {
  const CodingSuggestResult({
    required this.artifactId,
    required this.problems,
    this.label = codingReviewLabel,
  });

  factory CodingSuggestResult.fromEnvelope({
    required String artifactId,
    required Map<String, dynamic> content,
  }) {
    final Object? raw = content['problems'];
    final List<CodingProblemBlock> blocks = <CodingProblemBlock>[];
    if (raw is List) {
      for (final Object item in raw) {
        blocks.add(CodingProblemBlock.fromJson(Json.map(item)));
      }
    }
    return CodingSuggestResult(
      artifactId: artifactId,
      problems: blocks,
      label: Json.string(content['label'], codingReviewLabel),
    );
  }

  final String artifactId;
  final List<CodingProblemBlock> problems;
  final String label;

  CodingProblemBlock? blockFor(String problemId) {
    for (final CodingProblemBlock b in problems) {
      if (b.problemId == problemId) return b;
    }
    return problems.isEmpty ? null : problems.first;
  }

  @override
  List<Object?> get props => <Object?>[artifactId, problems, label];
}

/// Accepted code stored on `problems.code_suggestion`.
class AcceptedCodeSuggestion extends Equatable {
  const AcceptedCodeSuggestion({
    required this.code,
    required this.description,
    this.billable = false,
    this.label = codingReviewLabel,
  });

  factory AcceptedCodeSuggestion.fromJson(Object? json) {
    final Map<String, dynamic> map = Json.map(json);
    return AcceptedCodeSuggestion(
      code: Json.string(map['code']).toUpperCase(),
      description: Json.string(map['description']),
      billable: Json.boolean(map['billable']),
      label: Json.string(map['label'], codingReviewLabel),
    );
  }

  final String code;
  final String description;
  final bool billable;
  final String label;

  @override
  List<Object?> get props => <Object?>[code, description, billable, label];
}
