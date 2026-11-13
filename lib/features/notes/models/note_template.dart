import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

/// Where a note section comes from. The user types some of them. The rest
/// are written from confirmed chart facts.
enum SectionSource {
  facts,
  clinicianSubjective,
  exam,
  update,
  support,
  plan,
  history;

  static SectionSource parse(Object? value) {
    switch (Json.string(value).toLowerCase()) {
      case 'clinician_subjective':
        return SectionSource.clinicianSubjective;
      case 'exam':
      case 'clinician_exam':
        return SectionSource.exam;
      case 'update':
      case 'clinician_update':
        return SectionSource.update;
      case 'support':
      case 'clinician_support':
        return SectionSource.support;
      case 'plan':
      case 'clinician_plan':
        return SectionSource.plan;
      case 'history':
      case 'clinician_history':
        return SectionSource.history;
    }
    // Anything else, including `facts` / `facts_and_exam`, is generated.
    return SectionSource.facts;
  }

  /// The clinician types this one.
  bool get isTyped => this != SectionSource.facts;

  /// Body field name for `POST /notes` (backend `resolveNoteInputs`).
  String? get wireField => switch (this) {
    SectionSource.clinicianSubjective => 'subjective',
    SectionSource.exam => 'exam',
    SectionSource.update => 'update',
    SectionSource.support => 'support',
    SectionSource.plan => 'plan',
    SectionSource.history => 'history',
    SectionSource.facts => null,
  };
}

String humanizeKey(String key) {
  final String words = key.replaceAll('_', ' ').trim();
  if (words.isEmpty) return '';
  return words[0].toUpperCase() + words.substring(1);
}

/// Admit H&P history keys the backend template uses (order preserved).
const List<(String, String)> historyFields = <(String, String)>[
  ('chief_complaint', 'Chief complaint'),
  ('hpi', 'HPI'),
  ('pmh', 'PMH'),
  ('medications', 'Medications'),
  ('allergies', 'Allergies'),
  ('family_history', 'Family history'),
  ('social_history', 'Social history'),
  ('ros', 'ROS'),
];

class TemplateSection extends Equatable {
  const TemplateSection({
    required this.key,
    required this.title,
    required this.source,
  });

  factory TemplateSection.fromJson(Object? json) {
    if (json is! Map) {
      final String key = Json.string(json);
      return TemplateSection(
        key: key,
        title: humanizeKey(key),
        source: SectionSource.facts,
      );
    }
    final Map<String, dynamic> map = Json.map(json);
    final String key = Json.firstString(map, const <String>['key', 'id']);
    final String title = Json.firstString(map, const <String>[
      'title',
      'label',
      'name',
    ]);
    // facts_and_exam: facts are generated; exam can still be typed separately
    // when the template also has a clinician_exam section.
    final String rawSource = Json.string(map['source']);
    final SectionSource source = rawSource == 'facts_and_exam'
        ? SectionSource.facts
        : SectionSource.parse(rawSource);
    return TemplateSection(
      key: key,
      title: title.isEmpty ? humanizeKey(key) : title,
      source: source,
    );
  }

  final String key;
  final String title;
  final SectionSource source;

  @override
  List<Object> get props => <Object>[key, title, source];
}

/// One note template: `progress`, `icu`, `admit_hp`.
class NoteTemplate extends Equatable {
  const NoteTemplate({
    required this.type,
    required this.name,
    required this.sections,
  });

  factory NoteTemplate.fromJson(Map<String, dynamic> json) {
    final String type = Json.firstString(json, const <String>[
      'note_type',
      'type',
      'id',
      'key',
    ]);
    final String name = Json.firstString(json, const <String>[
      'name',
      'title',
      'label',
    ]);
    final Object? raw = json['sections'];
    final List<TemplateSection> sections = raw is List
        ? raw
              .map(TemplateSection.fromJson)
              .where((TemplateSection s) => s.key.isNotEmpty)
              .toList()
        : const <TemplateSection>[];
    return NoteTemplate(
      type: type,
      name: name.isEmpty ? humanizeKey(type) : name,
      sections: sections,
    );
  }

  final String type;
  final String name;
  final List<TemplateSection> sections;

  /// The sections the clinician fills in.
  List<TemplateSection> get typedSections =>
      sections.where((TemplateSection s) => s.source.isTyped).toList();

  @override
  List<Object> get props => <Object>[type, name, sections];
}
