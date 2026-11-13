import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

/// How the patient relates to the study population. Missing details stay
/// in [unknown]; they are never guessed.
class Applicability extends Equatable {
  const Applicability({
    this.resembles = const <String>[],
    this.differs = const <String>[],
    this.unknown = const <String>[],
  });

  factory Applicability.fromJson(Map<String, dynamic> json) {
    return Applicability(
      resembles: _lines(json['resembles']),
      differs: _lines(json['differs']),
      unknown: _lines(json['unknown']),
    );
  }

  /// Backend may send plain strings or claim objects `{ text, ... }`.
  static List<String> _lines(Object? value) {
    if (value is! List) return const <String>[];
    final List<String> out = <String>[];
    for (final Object? item in value) {
      if (item is Map) {
        final String text = Json.firstString(Json.map(item), const <String>[
          'text',
          'statement',
          'claim',
        ]);
        if (text.isNotEmpty) out.add(text);
      } else {
        final String text = Json.string(item);
        if (text.isNotEmpty) out.add(text);
      }
    }
    return out;
  }

  final List<String> resembles;
  final List<String> differs;
  final List<String> unknown;

  @override
  List<Object> get props => <Object>[resembles, differs, unknown];
}

/// A study returned by the evidence search. Only retrieved records are
/// shown; nothing comes from model memory.
class EvidenceCard extends Equatable {
  const EvidenceCard({
    required this.id,
    required this.title,
    required this.journal,
    required this.studyType,
    required this.accessLevel,
    this.publicationDate,
    this.pmid,
    this.doi,
    this.url,
    this.population,
    this.outcomeSummary,
    this.limitations,
    this.applicability = const Applicability(),
  });

  factory EvidenceCard.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> explanation = Json.map(json['explanation']);
    return EvidenceCard(
      id: Json.string(json['id'] ?? json['evidence_id'] ?? json['pmid']),
      title: Json.string(json['title']),
      journal: Json.string(json['journal']),
      studyType: Json.string(json['study_type']),
      // When access is not known the card says so, it does not assume.
      accessLevel: Json.string(json['access_level'], 'Source not available'),
      publicationDate: Json.date(
        json['publication_date'] ?? json['date'] ?? json['year'],
      ),
      pmid: Json.stringOrNull(json['pmid']),
      doi: Json.stringOrNull(json['doi']),
      url: Json.stringOrNull(json['url']),
      population: Json.stringOrNull(json['population']),
      outcomeSummary: Json.stringOrNull(
        json['outcome_summary'] ?? explanation['what_found'],
      ),
      limitations: Json.stringOrNull(json['limitations']),
      applicability: Applicability.fromJson(
        Json.map(json['applicability'] ?? explanation['applicability']),
      ),
    );
  }

  final String id;
  final String title;
  final String journal;
  final String studyType;
  final String accessLevel;
  final DateTime? publicationDate;
  final String? pmid;
  final String? doi;
  final String? url;
  final String? population;
  final String? outcomeSummary;
  final String? limitations;
  final Applicability applicability;

  /// Opened outside the app. Null when there is no PMID.
  Uri? get pubmedUri =>
      pmid == null ? null : Uri.parse('https://pubmed.ncbi.nlm.nih.gov/$pmid/');

  @override
  List<Object?> get props => <Object?>[id, title, pmid, publicationDate];
}

/// How the search was run: shown with the results.
class EvidenceRetrieval extends Equatable {
  const EvidenceRetrieval({
    this.searchedAt,
    this.sources = const <String>[],
    this.filters = const <String>[],
    this.excludedRetracted = 0,
  });

  factory EvidenceRetrieval.fromJson(Map<String, dynamic> json) {
    return EvidenceRetrieval(
      searchedAt: Json.date(json['searched_at'] ?? json['search_date']),
      sources: Json.strings(json['sources']),
      filters: Json.strings(json['filters']),
      excludedRetracted: Json.integer(
        json['excluded_retracted'] ?? json['excluded_retracted_count'],
      ),
    );
  }

  final DateTime? searchedAt;
  final List<String> sources;
  final List<String> filters;
  final int excludedRetracted;

  @override
  List<Object?> get props => <Object?>[searchedAt, sources, filters];
}
