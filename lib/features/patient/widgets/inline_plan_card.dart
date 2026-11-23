import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/sync/census_sync_mark.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/patient/bloc/patient_overview_bloc.dart';
import 'package:round_ai/features/patient/models/plan_structured.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/problems/models/coding_suggestion.dart';
import 'package:round_ai/features/problems/widgets/coding_suggest_sheet.dart';

/// Assessment and Plan editable on the patient page, organized by problem.
class InlinePlanCard extends StatefulWidget {
  const InlinePlanCard({
    required this.patientId,
    required this.lines,
    this.structured,
    this.problems = const <Problem>[],
    super.key,
  });

  final String patientId;
  final List<String> lines;
  final PlanStructured? structured;
  final List<Problem> problems;

  @override
  State<InlinePlanCard> createState() => _InlinePlanCardState();
}

class _InlinePlanCardState extends State<InlinePlanCard> {
  late bool _includeIcd;
  bool _saving = false;
  bool _dirty = false;
  final List<_PlanEditors> _editors = <_PlanEditors>[];

  @override
  void initState() {
    super.initState();
    _includeIcd = widget.structured?.includeIcd ?? false;
    _rebuildEditors();
  }

  @override
  void didUpdateWidget(covariant InlinePlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dirty || _saving) return;
    final bool planChanged =
        oldWidget.structured != widget.structured ||
        oldWidget.lines != widget.lines ||
        oldWidget.problems != widget.problems;
    if (planChanged) {
      _includeIcd = widget.structured?.includeIcd ?? false;
      _rebuildEditors();
    }
  }

  @override
  void dispose() {
    for (final _PlanEditors e in _editors) {
      e.dispose();
    }
    super.dispose();
  }

  void _rebuildEditors() {
    for (final _PlanEditors e in _editors) {
      e.dispose();
    }
    _editors.clear();
    final PlanStructured? structured = widget.structured;
    if (structured != null && structured.items.isNotEmpty) {
      for (final PlanItem item in structured.items) {
        _editors.add(
          _PlanEditors.fromItem(
            item,
            fallbackCode: _codeFor(
              label: item.label,
              problemId: item.problemId,
            ),
          ),
        );
      }
      return;
    }
    final List<Problem> active = widget.problems
        .where(
          (Problem p) =>
              p.state == ProblemState.confirmed ||
              p.state == ProblemState.differential ||
              p.state == ProblemState.documented,
        )
        .toList();
    if (active.isNotEmpty) {
      for (final Problem p in active) {
        _editors.add(
          _PlanEditors(
            problemId: p.id,
            label: p.label,
            assessmentText: '',
            planText: '',
            code: p.codeSuggestion?.code,
          ),
        );
      }
      if (widget.lines.isNotEmpty && _editors.isNotEmpty) {
        _editors.first.plan.text = widget.lines.join('\n');
      }
      return;
    }
    _editors.add(
      _PlanEditors(
        problemId: null,
        label: '',
        assessmentText: '',
        planText: widget.lines.join('\n'),
      ),
    );
  }

  String? _codeFor({required String label, String? problemId}) {
    for (final Problem p in widget.problems) {
      final String? code = p.codeSuggestion?.code;
      if (code == null || code.isEmpty) continue;
      if (problemId != null && p.id == problemId) return code.trim();
      if (p.label.toLowerCase() == label.toLowerCase() ||
          label.toLowerCase().contains(p.label.toLowerCase())) {
        return code.trim();
      }
    }
    return null;
  }

  Problem? _problemFor(_PlanEditors e) {
    final String? id = e.problemId;
    if (id != null) {
      for (final Problem p in widget.problems) {
        if (p.id == id) return p;
      }
    }
    final String label = e.labelCtrl.text.trim().toLowerCase();
    if (label.isEmpty) return null;
    for (final Problem p in widget.problems) {
      if (p.label.toLowerCase() == label) return p;
    }
    return null;
  }

  PlanStructured _buildPlan() {
    return PlanStructured(
      includeIcd: _includeIcd,
      items: <PlanItem>[
        for (final _PlanEditors e in _editors)
          if (!e.isBlank)
            PlanItem(
              problemId: e.problemId,
              label: e.labelCtrl.text.trim().isEmpty
                  ? 'Assessment and Plan'
                  : e.labelCtrl.text.trim(),
              assessment: e.assessment.text.trim(),
              plan: e.plan.text.trim(),
              // Keep stored codes when toggle is off so turning it back on restores them.
              code: e.resolvedCode(widget.problems),
            ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final Result<void> result = await InjectionContainer
        .instance
        .patientRepository
        .saveStructuredPlan(widget.patientId, _buildPlan());
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result is Ok<void>) _dirty = false;
    });
    if (result case Err<void>()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save Assessment and Plan.')),
      );
      return;
    }
    markCensusDirty();
    context.read<PatientOverviewBloc>().add(const PatientOverviewRequested());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Assessment and Plan saved.')),
    );
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _reviewIcd(_PlanEditors editor) async {
    final Problem? problem = _problemFor(editor);
    if (problem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Link this row to a confirmed problem before reviewing ICD codes.',
          ),
        ),
      );
      return;
    }
    if (problem.state == ProblemState.differential) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Differential problems cannot receive a confirmed ICD code. '
            'Confirm the diagnosis first, or leave the code blank.',
          ),
        ),
      );
      return;
    }
    final AcceptedCodeSuggestion? accepted = await showCodingSuggestSheet(
      context,
      patientId: widget.patientId,
      problem: problem,
      repository: InjectionContainer.instance.problemsRepository,
      aiRepository: InjectionContainer.instance.aiRepository,
    );
    if (!mounted || accepted == null) return;
    setState(() {
      editor.code = accepted.code;
      _dirty = true;
    });
    context.read<PatientOverviewBloc>().add(const PatientOverviewRequested());
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool hasAnyAcceptedCode = widget.problems.any(
      (Problem p) =>
          p.codeSuggestion?.code != null &&
          p.codeSuggestion!.code.trim().isNotEmpty,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Assessment and Plan',
                  style: AppTypography.semiBold(fontSize: 15),
                ),
              ),
              TextButton(
                onPressed: () =>
                    context.push(AppRoutes.patientPlanPath(widget.patientId)),
                child: Text(
                  'Full editor',
                  style: AppTypography.semiBold(
                    fontSize: 12,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Edit by problem on this page. AI never writes this section. '
            'ICD codes attach only to documented diagnoses you accept.',
            style: AppTypography.regular(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Include ICD-10 codes',
              style: AppTypography.regular(
                fontSize: 13,
                color: colors.textPrimary,
              ),
            ),
            subtitle: Text(
              hasAnyAcceptedCode
                  ? 'Shows accepted codes beside diagnoses. Clinical wording stays the same when you toggle.'
                  : 'No accepted codes yet. Use Review ICD on a problem — codes are not invented.',
              style: AppTypography.regular(
                fontSize: 11,
                color: colors.textMuted,
              ),
            ),
            value: _includeIcd,
            onChanged: _saving
                ? null
                : (bool value) {
                    setState(() {
                      _includeIcd = value;
                      _dirty = true;
                      if (value) {
                        for (final _PlanEditors e in _editors) {
                          e.code ??= _codeFor(
                            label: e.labelCtrl.text,
                            problemId: e.problemId,
                          );
                        }
                      }
                    });
                  },
          ),
          for (int i = 0; i < _editors.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 12),
            _ProblemPlanBlock(
              editor: _editors[i],
              includeIcd: _includeIcd,
              problems: widget.problems,
              onChanged: _markDirty,
              onReviewIcd: _saving ? null : () => _reviewIcd(_editors[i]),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _saving
                ? null
                : () {
                    setState(() {
                      _editors.add(
                        _PlanEditors(
                          problemId: null,
                          label: '',
                          assessmentText: '',
                          planText: '',
                        ),
                      );
                      _dirty = true;
                    });
                  },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add problem'),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0A8F9C),
                foregroundColor: colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: _saving || !_dirty ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save Assessment and Plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemPlanBlock extends StatelessWidget {
  const _ProblemPlanBlock({
    required this.editor,
    required this.includeIcd,
    required this.problems,
    required this.onChanged,
    this.onReviewIcd,
  });

  final _PlanEditors editor;
  final bool includeIcd;
  final List<Problem> problems;
  final VoidCallback onChanged;
  final VoidCallback? onReviewIcd;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final String? code = includeIcd ? editor.resolvedCode(problems) : null;
    final bool needsCode =
        includeIcd && (code == null || code.trim().isEmpty);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: editor.labelCtrl,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: 'Problem',
              isDense: true,
              suffixText: code == null || code.isEmpty ? null : code,
            ),
            style: AppTypography.semiBold(fontSize: 14),
          ),
          if (includeIcd) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: onReviewIcd,
                  icon: const Icon(Icons.medical_information_outlined, size: 16),
                  label: Text(
                    code == null || code.isEmpty
                        ? 'Review ICD'
                        : 'Change ICD',
                    style: AppTypography.medium(fontSize: 12),
                  ),
                ),
                if (code != null && code.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      code,
                      style: AppTypography.semiBold(
                        fontSize: 12,
                        color: colors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            if (needsCode)
              Text(
                'Code needed — documentation may be insufficient for a specific '
                'ICD. Review suggestions, or leave blank. Do not invent a diagnosis.',
                style: AppTypography.regular(
                  fontSize: 12,
                  color: colors.warning,
                ),
              ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: editor.assessment,
            onChanged: (_) => onChanged(),
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Assessment',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: editor.plan,
            onChanged: (_) => onChanged(),
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Plan',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanEditors {
  _PlanEditors({
    required this.problemId,
    required String label,
    required String assessmentText,
    required String planText,
    this.code,
  }) : labelCtrl = TextEditingController(text: label),
       assessment = TextEditingController(text: assessmentText),
       plan = TextEditingController(text: planText);

  factory _PlanEditors.fromItem(PlanItem item, {String? fallbackCode}) {
    return _PlanEditors(
      problemId: item.problemId,
      label: item.label,
      assessmentText: item.assessment,
      planText: item.plan,
      code: (item.code != null && item.code!.isNotEmpty)
          ? item.code
          : fallbackCode,
    );
  }

  final String? problemId;
  final TextEditingController labelCtrl;
  final TextEditingController assessment;
  final TextEditingController plan;
  String? code;

  String? resolvedCode(List<Problem> problems) {
    if (code != null && code!.trim().isNotEmpty) return code!.trim();
    final String label = labelCtrl.text.trim().toLowerCase();
    for (final Problem p in problems) {
      final String? c = p.codeSuggestion?.code;
      if (c == null || c.isEmpty) continue;
      if (problemId != null && p.id == problemId) return c.trim();
      if (p.label.toLowerCase() == label) return c.trim();
    }
    return null;
  }

  bool get isBlank =>
      labelCtrl.text.trim().isEmpty &&
      assessment.text.trim().isEmpty &&
      plan.text.trim().isEmpty;

  void dispose() {
    labelCtrl.dispose();
    assessment.dispose();
    plan.dispose();
  }
}
