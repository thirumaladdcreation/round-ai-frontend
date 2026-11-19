import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

class PlanItem extends Equatable {
  const PlanItem({
    this.problemId,
    this.label = '',
    this.assessment = '',
    this.plan = '',
    this.code,
  });

  factory PlanItem.fromJson(Map<String, dynamic> json) {
    return PlanItem(
      problemId: Json.stringOrNull(json['problem_id']),
      label: Json.string(json['label']),
      assessment: Json.string(json['assessment']),
      plan: Json.string(json['plan']),
      code: Json.stringOrNull(json['code']),
    );
  }

  final String? problemId;
  final String label;
  final String assessment;
  final String plan;
  final String? code;

  Map<String, Object?> toJson() => <String, Object?>{
        'problem_id': problemId,
        'label': label,
        'assessment': assessment,
        'plan': plan,
        if (code != null && code!.isNotEmpty) 'code': code,
      };

  PlanItem copyWith({
    String? problemId,
    String? label,
    String? assessment,
    String? plan,
    String? code,
    bool clearCode = false,
  }) {
    return PlanItem(
      problemId: problemId ?? this.problemId,
      label: label ?? this.label,
      assessment: assessment ?? this.assessment,
      plan: plan ?? this.plan,
      code: clearCode ? null : (code ?? this.code),
    );
  }

  bool get isEmpty =>
      label.trim().isEmpty &&
      assessment.trim().isEmpty &&
      plan.trim().isEmpty;

  @override
  List<Object?> get props => <Object?>[problemId, label, assessment, plan, code];
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
  List<String> toDisplayLines({bool withIcd = false}) {
    final List<String> lines = <String>[];
    for (final PlanItem item in items) {
      final String title = item.label.isEmpty
          ? 'Assessment and Plan'
          : (withIcd && item.code != null && item.code!.isNotEmpty
              ? '${item.label} (${item.code})'
              : item.label);
      lines.add(title);
      if (item.assessment.isNotEmpty) {
        lines.add('Assessment: ${item.assessment}');
      }
      if (item.plan.isNotEmpty) lines.add('Plan: ${item.plan}');
    }
    return lines;
  }

  @override
  List<Object?> get props => <Object?>[includeIcd, items];
}
