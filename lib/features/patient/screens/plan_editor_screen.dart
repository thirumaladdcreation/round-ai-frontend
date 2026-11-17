import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/patient/bloc/save_cubit.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/app_input.dart';

/// Today's Assessment and Plan, typed by the clinician. AI never writes it.
class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({required this.patientId, this.repository, super.key});

  final String patientId;
  final PatientRepository? repository;

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  final TextEditingController _text = TextEditingController();
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

  /// Clinical wording without codes — preserved when toggling ICD on/off.
  String _clinicalText = '';

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
          _clinicalText = value.planToday.join('\n');
          _text.text = _clinicalText;
          _loadError = null;
        case Err<PatientDetail>(:final failure):
          _loadError = failure.message;
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _cubit.close();
    super.dispose();
  }

  void _applyIcdToggle(bool include) {
    setState(() {
      if (_includeIcd && !include) {
        // Turning off: restore clinical wording (strip codes we appended).
        _text.text = _clinicalText;
      } else if (!_includeIcd && include) {
        // Turning on: keep current clinical text as base, then append codes.
        _clinicalText = _stripCodes(_text.text);
        _text.text = _withCodes(_clinicalText);
      }
      _includeIcd = include;
    });
  }

  String _stripCodes(String raw) {
    return raw
        .split('\n')
        .map((String line) {
          return line
              .replaceAll(RegExp(r'\s*\([A-Z]\d{2}(?:\.\d{1,4})?\)\s*$'), '')
              .trimRight();
        })
        .join('\n');
  }

  String _withCodes(String raw) {
    return raw
        .split('\n')
        .map((String line) {
          final String trimmed = line.trimRight();
          if (trimmed.isEmpty) return line;
          for (final Problem p in _problems) {
            final String? code = p.codeSuggestion?.code;
            if (code == null || code.isEmpty) continue;
            if (trimmed.toLowerCase().contains(p.label.toLowerCase())) {
              if (trimmed.contains(code)) return trimmed;
              return '$trimmed ($code)';
            }
          }
          return trimmed;
        })
        .join('\n');
  }

  void _save() {
    // Persist the clinical wording the clinician sees (with or without codes).
    final String toSave = _text.text;
    if (!_includeIcd) {
      _clinicalText = toSave;
    } else {
      _clinicalText = _stripCodes(toSave);
    }
    final List<String> lines = toSave
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
    _cubit.save(lines);
  }

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
                      'Organize by problem (problem, then plan under it). '
                      'AI never writes this section. Dictation that includes a '
                      'plan can prefill it after note review.',
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
                                'Toggle keeps your clinical wording.'
                            : 'No accepted codes on problems yet. Confirm '
                                'problems and accept ICD suggestions first — '
                                'codes are not invented for specificity.',
                        style: AppTypography.regular(
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                      ),
                      value: _includeIcd,
                      onChanged: _loadError != null ? null : _applyIcdToggle,
                    ),
                    if (_includeIcd && _problems.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      for (final Problem p in _problems)
                        if (p.codeSuggestion?.code != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${p.label} → ${p.codeSuggestion!.code}'
                              '${p.codeSuggestion!.description.isEmpty ? '' : ' · ${p.codeSuggestion!.description}'}',
                              style: AppTypography.regular(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                          )
                        else if (p.state.canSuggestCodes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${p.label} — code needed (review documentation)',
                              style: AppTypography.regular(
                                fontSize: 12,
                                color: colors.warning,
                              ),
                            ),
                          ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _text,
                      enabled: _loadError == null,
                      minLines: 8,
                      maxLines: 16,
                      keyboardType: TextInputType.multiline,
                      onChanged: (String v) {
                        if (!_includeIcd) _clinicalText = v;
                      },
                      decoration: appInputDecoration(
                        context,
                        label: 'Assessment and Plan',
                        hint:
                            'AKI — hold diuresis; recheck creatinine this evening\n'
                            'CAP — continue ceftriaxone; follow cultures',
                      ),
                    ),
                    const FreeTextHint(),
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
