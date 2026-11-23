import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

class PlanItem extends Equatable {
  const PlanItem({
    this.problemId,
    this.label = '',
    this.assessment = '',
    this.plan = '',
    this.code,
    this.source = 'clinician',
    this.status = 'draft',
    this.manuallyEdited = false,
    this.updatedAt,
  });

  factory PlanItem.fromJson(Map<String, dynamic> json) {
    return PlanItem(
      problemId: Json.stringOrNull(json['problem_id']),
      label: Json.string(json['label']),
      assessment: Json.string(
        json['assessment'] ?? json['assessment_text'],
      ),
      plan: Json.string(json['plan'] ?? json['plan_text']),
      code: Json.stringOrNull(json['code']),
      source: Json.string(json['source'], 'clinician'),
      status: Json.string(json['status'], 'draft'),
      manuallyEdited: Json.boolean(json['manually_edited']),
      updatedAt: Json.stringOrNull(json['updated_at']),
    );
  }

  final String? problemId;
  final String label;
  final String assessment;
  final String plan;
  final String? code;
  final String source;
  final String status;
  final bool manuallyEdited;
  final String? updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'problem_id': problemId,
        'label': label,
        'assessment': assessment,
        'plan': plan,
        if (code != null && code!.isNotEmpty) 'code': code,
        'source': source,
        'status': status,
        'manually_edited': manuallyEdited,
        if (updatedAt != null) 'updated_at': updatedAt,
      };

  PlanItem copyWith({
    String? problemId,
    String? label,
    String? assessment,
    String? plan,
    String? code,
    bool clearCode = false,
    String? source,
    String? status,
    bool? manuallyEdited,
    String? updatedAt,
  }) {
    return PlanItem(
      problemId: problemId ?? this.problemId,
      label: label ?? this.label,
      assessment: assessment ?? this.assessment,
      plan: plan ?? this.plan,
      code: clearCode ? null : (code ?? this.code),
      source: source ?? this.source,
      status: status ?? this.status,
      manuallyEdited: manuallyEdited ?? this.manuallyEdited,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isEmpty =>
      label.trim().isEmpty &&
      assessment.trim().isEmpty &&
      plan.trim().isEmpty;

  @override
  List<Object?> get props => <Object?>[
        problemId,
        label,
        assessment,
        plan,
        code,
        source,
        status,
        manuallyEdited,
      ];
}

class PlanStructured extends Equatable {
  const PlanStructured({
    this.includeIcd = false,
    this.items = const <PlanItem>[],
  });

  factory PlanStructured.fromJson(Object? json) {
    if (json is! Map) return const PlanStructured();
    final Map<String, dynamic> map = Json.map(json);
    return PlanStructured(
      includeIcd: Json.boolean(map['include_icd']),
      items: Json.maps(map['items']).map(PlanItem.fromJson).toList(),
    );
  }

  final bool includeIcd;
  final List<PlanItem> items;

  Map<String, Object> toJson() => <String, Object>{
        'version': 1,
        'include_icd': includeIcd,
        'items': items.map((PlanItem i) => i.toJson()).toList(),
      };

  PlanStructured copyWith({bool? includeIcd, List<PlanItem>? items}) {
    return PlanStructured(
      includeIcd: includeIcd ?? this.includeIcd,
      items: items ?? this.items,
    );
  }

  /// Flat lines for legacy UIs / note prefill without structure.
  /// [codeForLabel] resolves accepted codes when [item.code] is empty.
  List<String> toDisplayLines({
    bool withIcd = false,
    String? Function(PlanItem item)? codeForLabel,
  }) {
    final List<String> lines = <String>[];
    for (final PlanItem item in items) {
      final String? code = withIcd
          ? ((item.code != null && item.code!.isNotEmpty)
              ? item.code
              : codeForLabel?.call(item))
          : null;
      final String title = item.label.isEmpty
          ? 'Assessment and Plan'
          : (code != null && code.isNotEmpty
              ? '${item.label} ($code)'
              : item.label);
      lines.add(title);
      if (item.assessment.isNotEmpty) {
        lines.add('Assessment: ${item.assessment}');
      }
      if (item.plan.isNotEmpty) lines.add('Plan: ${item.plan}');
    }
    return lines;
  }

  /// Parses problem-wise A&P text (title / Assessment: / Plan: blocks).
  /// Returns null when the text is not organized by problem.
  static PlanStructured? tryParseNoteText(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return null;
    final List<String> lines = text
        .split('\n')
        .map((String l) => l.trim())
        .where((String l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    final List<PlanItem> items = <PlanItem>[];
    String? label;
    final StringBuffer assessment = StringBuffer();
    final StringBuffer plan = StringBuffer();
    String mode = 'label'; // label | assessment | plan

    void flush() {
      if (label == null && assessment.isEmpty && plan.isEmpty) return;
      final PlanItem item = PlanItem(
        label: (label ?? '').trim(),
        assessment: assessment.toString().trim(),
        plan: plan.toString().trim(),
      );
      if (!item.isEmpty) items.add(item);
      label = null;
      assessment.clear();
      plan.clear();
      mode = 'label';
    }

    final RegExp assessRe = RegExp(r'^assessment\s*:\s*(.*)$', caseSensitive: false);
    final RegExp planRe = RegExp(r'^plan\s*:\s*(.*)$', caseSensitive: false);
    final RegExp headingRe = RegExp(
      r'^(?:#{1,3}\s*|\d+[.)]\s*)?(.+?)(?:\s*\([A-Z]\d[\w.]+\))?$',
    );

    for (final String line in lines) {
      final Match? a = assessRe.firstMatch(line);
      if (a != null) {
        mode = 'assessment';
        final String rest = (a.group(1) ?? '').trim();
        if (rest.isNotEmpty) {
          if (assessment.isNotEmpty) assessment.writeln();
          assessment.write(rest);
        }
        continue;
      }
      final Match? p = planRe.firstMatch(line);
      if (p != null) {
        mode = 'plan';
        final String rest = (p.group(1) ?? '').trim();
        if (rest.isNotEmpty) {
          if (plan.isNotEmpty) plan.writeln();
          plan.write(rest);
        }
        continue;
      }
      // New problem heading when we already collected content for the prior one.
      final bool looksLikeHeading = mode == 'label' ||
          ((assessment.isNotEmpty || plan.isNotEmpty) &&
              !line.toLowerCase().startsWith('assessment') &&
              !line.toLowerCase().startsWith('plan'));
      if (looksLikeHeading &&
          (assessment.isNotEmpty || plan.isNotEmpty || (label != null && mode != 'label'))) {
        flush();
      }
      if (mode == 'assessment') {
        if (assessment.isNotEmpty) assessment.writeln();
        assessment.write(line);
      } else if (mode == 'plan') {
        if (plan.isNotEmpty) plan.writeln();
        plan.write(line);
      } else {
        final Match? h = headingRe.firstMatch(line);
        label = (h?.group(1) ?? line).trim();
        mode = 'label';
      }
    }
    flush();

    // Need at least one item with a plan or assessment under a label.
    final List<PlanItem> usable = items
        .where(
          (PlanItem i) =>
              i.label.isNotEmpty && (i.assessment.isNotEmpty || i.plan.isNotEmpty),
        )
        .toList();
    if (usable.length < 1) return null;
    // Single unlabeled blob with no Assessment:/Plan: markers is not structured.
    if (usable.length == 1 &&
        !RegExp(r'assessment\s*:|plan\s*:', caseSensitive: false).hasMatch(text)) {
      return null;
    }
    return PlanStructured(items: usable);
  }

  @override
  List<Object?> get props => <Object?>[includeIcd, items];
}
