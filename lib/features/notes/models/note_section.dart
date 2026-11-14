import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/models/summary_content.dart';
import 'package:round_ai/features/notes/models/note_template.dart';

/// A check the backend ran on a section, such as a number that is not in the
/// chart. A section with a flag cannot be marked reviewed.
class NoteFlag extends Equatable {
  const NoteFlag({required this.text, this.code});

  factory NoteFlag.parse(Object? json) {
    if (json is Map) {
      final Map<String, dynamic> map = Json.map(json);
      final String code = Json.firstString(map, const <String>[
        'code',
        'type',
        'kind',
      ]);
      final String message = Json.firstString(map, const <String>[
        'message',
        'text',
        'detail',
      ]);
      return NoteFlag(
        text: message.isEmpty ? humanizeKey(code) : message,
        code: code.isEmpty ? null : code,
      );
    }
    final String text = Json.string(json);
    return NoteFlag(text: text.contains('_') ? humanizeKey(text) : text);
  }

  final String text;
  final String? code;

  @override
  List<Object?> get props => <Object?>[text, code];
}

/// Character span into the dictation transcript.
class TranscriptSpan extends Equatable {
  const TranscriptSpan({required this.start, required this.end});

  factory TranscriptSpan.fromJson(Object? json) {
    final Map<String, dynamic> map = Json.map(json);
    return TranscriptSpan(
      start: Json.integer(map['start']),
      end: Json.integer(map['end']),
    );
  }

  final int start;
  final int end;

  @override
  List<Object?> get props => <Object?>[start, end];
}

/// One cleaned clinical sentence with optional transcript spans.
class NoteSentence extends Equatable {
  const NoteSentence({
    required this.text,
    this.spans = const <TranscriptSpan>[],
    this.factIds = const <String>[],
  });

  factory NoteSentence.fromJson(Object? json) {
    final Map<String, dynamic> map = Json.map(json);
    final Object? rawSpans = map['spans'];
    return NoteSentence(
      text: Json.firstString(map, const <String>['text', 'content']),
      spans: rawSpans is List
          ? rawSpans.map(TranscriptSpan.fromJson).toList()
          : const <TranscriptSpan>[],
      factIds: Json.strings(map['fact_ids']),
    );
  }

  final String text;
  final List<TranscriptSpan> spans;
  final List<String> factIds;

  @override
  List<Object?> get props => <Object?>[text, spans, factIds];
}

/// Ambiguous phrase the scribe will not guess.
class NeedsClarification extends Equatable {
  const NeedsClarification({
    required this.phrase,
    required this.question,
    this.spans = const <TranscriptSpan>[],
  });

  factory NeedsClarification.fromJson(Object? json) {
    final Map<String, dynamic> map = Json.map(json);
    final Object? rawSpans = map['spans'];
    return NeedsClarification(
      phrase: Json.string(map['phrase']),
      question: Json.string(map['question']),
      spans: rawSpans is List
          ? rawSpans.map(TranscriptSpan.fromJson).toList()
          : const <TranscriptSpan>[],
    );
  }

  final String phrase;
  final String question;
  final List<TranscriptSpan> spans;

  @override
  List<Object?> get props => <Object?>[phrase, question, spans];
}

/// One section of a note draft.
class NoteSection extends Equatable {
  const NoteSection({
    required this.key,
    required this.title,
    required this.text,
    this.source,
    this.flags = const <NoteFlag>[],
    this.factIds = const <String>[],
    this.sentences = const <NoteSentence>[],
  });

  factory NoteSection.fromJson(String fallbackKey, Object? json) {
    if (json is! Map) {
      return NoteSection(
        key: fallbackKey,
        title: humanizeKey(fallbackKey),
        text: Json.string(json),
      );
    }
    final Map<String, dynamic> map = Json.map(json);
    final String key = Json.firstString(map, const <String>['key', 'id']);
    final String title = Json.firstString(map, const <String>[
      'title',
      'label',
      'name',
    ]);
    final Object? rawFlags = map['flags'];
    final Object? rawSentences = map['sentences'];
    return NoteSection(
      key: key.isEmpty ? fallbackKey : key,
      title: title.isEmpty
          ? humanizeKey(key.isEmpty ? fallbackKey : key)
          : title,
      text: Json.firstString(map, const <String>['text', 'content']),
      source: map['source'] == null ? null : SectionSource.parse(map['source']),
      flags: rawFlags is List
          ? rawFlags.map(NoteFlag.parse).toList()
          : const <NoteFlag>[],
      factIds: Json.strings(map['fact_ids']),
      sentences: rawSentences is List
          ? rawSentences.map(NoteSentence.fromJson).toList()
          : const <NoteSentence>[],
    );
  }

  final String key;
  final String title;
  final String text;

  /// Where it came from, when the backend says.
  final SectionSource? source;
  final List<NoteFlag> flags;

  /// The chart facts behind this section. Each one opens the source drawer.
  final List<String> factIds;

  /// Scribe sentences with transcript spans (when `scribe_mode` is set).
  final List<NoteSentence> sentences;

  bool get hasPlaceholders => hasPlaceholder(text);
  bool get hasFlags => flags.isNotEmpty;

  /// Said only when the backend told us the source.
  String? get originLabel {
    final SectionSource? s = source;
    if (s == null) return null;
    return s == SectionSource.facts ? 'From chart' : 'Clinician entered';
  }

  NoteSection withExtraFlags(List<NoteFlag> extra) {
    if (extra.isEmpty) return this;
    return NoteSection(
      key: key,
      title: title,
      text: text,
      source: source,
      flags: <NoteFlag>[...flags, ...extra],
      factIds: factIds,
      sentences: sentences,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    key,
    title,
    text,
    source,
    flags,
    factIds,
    sentences,
  ];
}

/// A dictation/image source that filled an empty note field.
class FedFromSource extends Equatable {
  const FedFromSource({
    required this.sourceId,
    required this.field,
    this.kind,
  });

  factory FedFromSource.fromJson(Object? json) {
    final Map<String, dynamic> map = Json.map(json);
    return FedFromSource(
      sourceId: Json.firstString(map, const <String>['source_id', 'id']),
      field: Json.string(map['field']),
      kind: Json.stringOrNull(map['kind']),
    );
  }

  final String sourceId;
  final String field;
  final String? kind;

  @override
  List<Object?> get props => <Object?>[sourceId, field, kind];
}

/// What a note envelope holds in `content`.
class NoteContent extends Equatable {
  const NoteContent({
    required this.sections,
    this.fedFromSources = const <FedFromSource>[],
    this.needsClarification = const <NeedsClarification>[],
    this.transcript = '',
    this.scribeMode = false,
  });

  factory NoteContent.fromEnvelope(AiEnvelope envelope) {
    final Object? raw = envelope.content['sections'];
    final List<NoteSection> sections = <NoteSection>[];
    if (raw is Map) {
      for (final MapEntry<dynamic, dynamic> e in raw.entries) {
        sections.add(NoteSection.fromJson(e.key.toString(), e.value));
      }
    } else if (raw is List) {
      for (int i = 0; i < raw.length; i++) {
        sections.add(NoteSection.fromJson('section_${i + 1}', raw[i]));
      }
    }
    // Issues that name a section become flags on it.
    final Map<String, List<NoteFlag>> byKey = <String, List<NoteFlag>>{};
    for (final ValidationIssue issue in envelope.validationIssues) {
      final String? key = issue.section;
      if (key == null) continue;
      byKey
          .putIfAbsent(key, () => <NoteFlag>[])
          .add(
            NoteFlag(
              text: issue.message.isEmpty
                  ? humanizeKey(issue.code ?? 'flag')
                  : issue.message,
              code: issue.code,
            ),
          );
    }
    final Object? fedRaw = envelope.content['fed_from_sources'];
    final List<FedFromSource> fed = fedRaw is List
        ? fedRaw
              .map(FedFromSource.fromJson)
              .where((FedFromSource f) => f.sourceId.isNotEmpty)
              .toList()
        : const <FedFromSource>[];
    final Object? clarifyRaw = envelope.content['needs_clarification'];
    final List<NeedsClarification> clarify = clarifyRaw is List
        ? clarifyRaw.map(NeedsClarification.fromJson).toList()
        : const <NeedsClarification>[];
    return NoteContent(
      sections: <NoteSection>[
        for (final NoteSection s in sections)
          s.withExtraFlags(<NoteFlag>[
            for (final NoteFlag f in byKey[s.key] ?? const <NoteFlag>[])
              if (!s.flags.contains(f)) f,
          ]),
      ],
      fedFromSources: fed,
      needsClarification: clarify,
      transcript: Json.string(envelope.content['transcript']),
      scribeMode: Json.string(envelope.content['scribe_mode']) == 'from_dictation',
    );
  }

  final List<NoteSection> sections;
  final List<FedFromSource> fedFromSources;
  final List<NeedsClarification> needsClarification;
  final String transcript;
  final bool scribeMode;

  @override
  List<Object> get props => <Object>[
    sections,
    fedFromSources,
    needsClarification,
    transcript,
    scribeMode,
  ];
}

/// New text for one section, proposed by the model. Nothing changes until
/// the clinician taps Apply.
class RewriteProposal extends Equatable {
  const RewriteProposal({
    required this.sectionKey,
    required this.mode,
    required this.before,
    required this.after,
  });

  final String sectionKey;
  final RewriteMode mode;
  final String before;
  final String after;

  @override
  List<Object> get props => <Object>[sectionKey, mode, before, after];
}

enum RewriteMode {
  regenerate('Regenerate', 'regenerate'),
  shorten('Shorten', 'shorten'),
  expand('Expand', 'expand'),
  improve('Improve', 'improve');

  const RewriteMode(this.label, this.wire);

  final String label;
  final String wire;
}
