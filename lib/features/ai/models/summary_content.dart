import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';

/// Text the chart did not have, written by the backend as `[... not entered]`.
/// It is shown highlighted and it blocks "Mark reviewed".
final RegExp notEnteredPlaceholder = RegExp(
  r'\[[^\]]*not entered[^\]]*\]',
  caseSensitive: false,
);

bool hasPlaceholder(String text) => notEnteredPlaceholder.hasMatch(text);

/// One section of a summary. A section is either a list of claims, each with
/// its own sources, or plain text.
class SummarySection extends Equatable {
  const SummarySection({
    required this.key,
    required this.title,
    this.text = '',
    this.claims = const <Claim>[],
  });

  factory SummarySection.fromJson(String fallbackKey, Object? json) {
    if (json is Map) {
      final Map<String, dynamic> map = Json.map(json);
      final String key = Json.firstString(map, const <String>['key', 'id']);
      final String title = Json.firstString(map, const <String>[
        'title',
        'label',
        'name',
      ]);
      final Object? body = map['claims'] ?? map['items'] ?? map['lines'];
      return SummarySection(
        key: key.isEmpty ? fallbackKey : key,
        title: title.isEmpty
            ? _humanize(key.isEmpty ? fallbackKey : key)
            : title,
        text: Json.firstString(map, const <String>['text', 'content']),
        claims: Claim.list(body),
      );
    }
    if (json is List) {
      return SummarySection(
        key: fallbackKey,
        title: _humanize(fallbackKey),
        claims: Claim.list(json),
      );
    }
    return SummarySection(
      key: fallbackKey,
      title: _humanize(fallbackKey),
      text: Json.string(json),
    );
  }

  static String _humanize(String key) {
    final String words = key.replaceAll('_', ' ').trim();
    if (words.isEmpty) return 'Section';
    return words[0].toUpperCase() + words.substring(1);
  }

  final String key;
  final String title;
  final String text;
  final List<Claim> claims;

  bool get isEmpty => text.isEmpty && claims.isEmpty;

  /// True when any part still has "not entered" text.
  bool get hasPlaceholders =>
      hasPlaceholder(text) || claims.any((Claim c) => hasPlaceholder(c.text));

  @override
  List<Object> get props => <Object>[key, title, text, claims];
}

/// What `POST /summary` puts in `content`.
class SummaryContent extends Equatable {
  const SummaryContent({
    this.oneLiner,
    this.sections = const <SummarySection>[],
    this.missingInformation = const <String>[],
    this.conflicts = const <InsightItem>[],
    this.truncated = false,
  });

  factory SummaryContent.fromEnvelope(AiEnvelope envelope) {
    final Map<String, dynamic> c = envelope.content;
    final Object? oneLiner = c['one_liner'];
    final Object? rawSections = c['sections'];
    final List<SummarySection> sections = <SummarySection>[];
    if (rawSections is Map) {
      for (final MapEntry<dynamic, dynamic> e in rawSections.entries) {
        sections.add(SummarySection.fromJson(e.key.toString(), e.value));
      }
    } else if (rawSections is List) {
      for (int i = 0; i < rawSections.length; i++) {
        sections.add(
          SummarySection.fromJson('section_${i + 1}', rawSections[i]),
        );
      }
    }
    final Claim? one = oneLiner == null ? null : Claim.parse(oneLiner);
    return SummaryContent(
      oneLiner: one == null || one.text.isEmpty ? null : one,
      sections: sections.where((SummarySection s) => !s.isEmpty).toList(),
      missingInformation: InsightItem.list(c['missing_information'])
          .map((InsightItem i) => i.label.isEmpty ? i.text : i.label)
          .where((String s) => s.isNotEmpty)
          .toSet()
          .toList(),
      conflicts: InsightItem.list(c['conflicts']),
      truncated: _truthy(c['truncated']),
    );
  }

  /// A flag, or a note about what was cut. Anything present counts.
  static bool _truthy(Object? value) {
    if (value == null || value == false) return false;
    if (value is String) return value.isNotEmpty && value != 'false';
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    if (value is num) return value != 0;
    return true;
  }

  final Claim? oneLiner;
  final List<SummarySection> sections;
  final List<String> missingInformation;
  final List<InsightItem> conflicts;

  /// The chart was too long and part of it was left out.
  final bool truncated;

  /// Keys of the sections that still have "not entered" text.
  List<String> get placeholderSections => <String>[
    if (oneLiner != null && hasPlaceholder(oneLiner!.text)) 'one_liner',
    for (final SummarySection s in sections)
      if (s.hasPlaceholders) s.key,
  ];

  bool get hasPlaceholders => placeholderSections.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[
    oneLiner,
    sections,
    missingInformation,
    conflicts,
    truncated,
  ];
}
