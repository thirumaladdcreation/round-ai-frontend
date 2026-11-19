import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/patient/bloc/save_cubit.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/models/plan_structured.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/app_input.dart';

/// Problem-wise Assessment and Plan. AI never writes this section.
class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({required this.patientId, this.repository, super.key});

  final String patientId;
  final PatientRepository? repository;

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  late final PatientRepository _repository =
      widget.repository ?? InjectionContainer.instance.patientRepository;
  late final PlanEditorCubit _cubit = PlanEditorCubit(
    _repository,
    widget.patientId,
  );
  bool _loading = true;
  String? _loadError;
  String _patientName = '';
  String _room = '';
  List<Problem> _problems = const <Problem>[];
  bool _includeIcd = false;
  final List<_ItemControllers> _items = <_ItemControllers>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final Result<PatientDetail> result = await _repository.loadDetail(
      widget.patientId,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case Ok<PatientDetail>(:final value):
          _patientName = value.patient.displayName;
          _room = value.patient.room;
          _problems = value.problems
              .where(
                (Problem p) =>
                    p.state == ProblemState.confirmed ||
                    p.state == ProblemState.differential ||
                    p.state == ProblemState.documented,
              )
              .toList();
          _includeIcd = value.planStructured?.includeIcd ?? false;
          _disposeItems();
          final PlanStructured? structured = value.planStructured;
          if (structured != null && structured.items.isNotEmpty) {
            for (final PlanItem item in structured.items) {
              _items.add(_ItemControllers.fromItem(item));
            }
          } else if (_problems.isNotEmpty) {
            for (final Problem p in _problems) {
              _items.add(
                _ItemControllers(
                  problemId: p.id,
                  label: p.label,
                  assessment: '',
                  plan: '',
                  code: p.codeSuggestion?.code,
                ),
              );
            }
            // Prefill plan lines into first matching problem when legacy text.
            if (value.planToday.isNotEmpty) {
              final String blob = value.planToday.join('\n');
              for (final _ItemControllers c in _items) {
                if (blob.toLowerCase().contains(c.label.text.toLowerCase()) &&
                    c.plan.text.isEmpty) {
                  c.plan.text = blob;
                  break;
                }
              }
            }
          } else {
            _items.add(
              _ItemControllers(
                problemId: null,
                label: '',
                assessment: '',
                plan: value.planToday.join('\n'),
              ),
            );
          }
          _loadError = null;
        case Err<PatientDetail>(:final failure):
          _loadError = failure.message;
      }
    });
  }

  void _disposeItems() {
    for (final _ItemControllers c in _items) {
      c.dispose();
    }
    _items.clear();
  }

  @override
  void dispose() {
    _disposeItems();
    _cubit.close();
    super.dispose();
  }

  void _addProblem() {
    setState(() {
      _items.add(
        _ItemControllers(problemId: null, label: '', assessment: '', plan: ''),
      );
    });
  }

  void _removeAt(int index) {
    setState(() {
      _items.removeAt(index).dispose();
      if (_items.isEmpty) {
        _items.add(
          _ItemControllers(
            problemId: null,
            label: '',
            assessment: '',
            plan: '',
          ),
        );
      }
    });
  }

  PlanStructured _buildPlan() {
    final List<PlanItem> items = <PlanItem>[
      for (final _ItemControllers c in _items)
        PlanItem(
          problemId: c.problemId,
          label: c.label.text.trim(),
          assessment: c.assessment.text.trim(),
          plan: c.plan.text.trim(),
          code: _includeIcd ? c.resolvedCode(_problems) : null,
        ),
    ].where((PlanItem i) => !i.isEmpty).toList();
    return PlanStructured(includeIcd: _includeIcd, items: items);
  }

  void _save() => _cubit.saveStructured(_buildPlan());

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool hasCodes = _problems.any(
      (Problem p) =>
          p.codeSuggestion?.code != null &&
          p.codeSuggestion!.code.trim().isNotEmpty,
    );
    return BlocConsumer<PlanEditorCubit, SaveState>(
      bloc: _cubit,
      listenWhen: (SaveState a, SaveState b) => b.saved && !a.saved,
      listener: (BuildContext context, SaveState state) => context.pop(),
      builder: (BuildContext context, SaveState state) {
        return ChartEntryScaffold(
          title: 'Assessment and Plan',
          patientName: _patientName,
          room: _room,
          bottom: AppButton(
            label: 'Save Assessment and Plan',
            loading: state.saving,
            onPressed: state.saving || _loading || _loadError != null
                ? null
                : _save,
          ),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Organize by problem. Assessment and Plan under each '
                      'issue. AI never writes this section. Dictation that '
                      'includes a plan can prefill it after note review.',
                      style: AppTypography.regular(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Include ICD-10 codes',
                        style: AppTypography.semiBold(
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        hasCodes
                            ? 'Accepted codes appear beside matching diagnoses. '
                                'Toggle keeps clinical wording.'
                            : 'No accepted codes yet. Confirm problems and '
                                'accept ICD suggestions first — codes are not invented.',
                        style: AppTypography.regular(
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                      ),
                      value: _includeIcd,
                      onChanged: _loadError != null
                          ? null
                          : (bool v) => setState(() => _includeIcd = v),
                    ),
                    const SizedBox(height: 8),
                    for (int i = 0; i < _items.length; i++) ...<Widget>[
                      _ProblemBlock(
                        index: i,
                        controllers: _items[i],
                        includeIcd: _includeIcd,
                        problems: _problems,
                        onRemove: _items.length > 1 ? () => _removeAt(i) : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextButton.icon(
                      onPressed: _loadError != null ? null : _addProblem,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add problem'),
                    ),
                    if (_loadError != null || state.error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        _loadError ?? state.error!,
                        style: AppTypography.regular(
                          fontSize: 13,
                          color: colors.error,
                        ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _ItemControllers {
  _ItemControllers({
    required this.problemId,
    required String label,
    required String assessment,
    required String plan,
    this.code,
  }) : label = TextEditingController(text: label),
       assessment = TextEditingController(text: assessment),
       plan = TextEditingController(text: plan);

  factory _ItemControllers.fromItem(PlanItem item) {
    return _ItemControllers(
      problemId: item.problemId,
      label: item.label,
      assessment: item.assessment,
      plan: item.plan,
      code: item.code,
    );
  }

  final String? problemId;
  final TextEditingController label;
  final TextEditingController assessment;
  final TextEditingController plan;
  final String? code;

  String? resolvedCode(List<Problem> problems) {
    if (code != null && code!.isNotEmpty) return code;
    for (final Problem p in problems) {
      if (problemId != null && p.id == problemId) {
        return p.codeSuggestion?.code;
      }
      if (p.label.toLowerCase() == label.text.trim().toLowerCase()) {
        return p.codeSuggestion?.code;
      }
    }
    return null;
  }

  void dispose() {
    label.dispose();
    assessment.dispose();
    plan.dispose();
  }
}

class _ProblemBlock extends StatelessWidget {
  const _ProblemBlock({
    required this.index,
    required this.controllers,
    required this.includeIcd,
    required this.problems,
    this.onRemove,
  });

  final int index;
  final _ItemControllers controllers;
  final bool includeIcd;
  final List<Problem> problems;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final String? code = includeIcd
        ? controllers.resolvedCode(problems)
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Problem ${index + 1}'
                  '${code == null || code.isEmpty ? '' : ' ($code)'}',
                  style: AppTypography.semiBold(
                    fontSize: 14,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controllers.label,
            decoration: appInputDecoration(
              context,
              label: 'Diagnosis / problem',
              hint: 'e.g. Acute kidney injury',
            ),
          ),
          if (includeIcd && (code == null || code.isEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Code needed — review documentation and accept an ICD suggestion.',
                style: AppTypography.regular(
                  fontSize: 12,
                  color: colors.warning,
                ),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: controllers.assessment,
            minLines: 2,
            maxLines: 5,
            decoration: appInputDecoration(
              context,
              label: 'Assessment',
              hint: 'Clinical assessment for this problem',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controllers.plan,
            minLines: 2,
            maxLines: 5,
            decoration: appInputDecoration(
              context,
              label: 'Plan',
              hint: 'Clinician-entered plan only',
            ),
          ),
        ],
      ),
    );
  }
}
