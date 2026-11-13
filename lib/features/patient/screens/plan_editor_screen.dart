import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/patient/bloc/save_cubit.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/app_input.dart';

/// Today's plan, typed by the clinician. AI never writes or changes it.
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
          _text.text = value.planToday.join('\n');
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

  void _save() {
    final List<String> lines = _text.text
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
    _cubit.save(lines);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocConsumer<PlanEditorCubit, SaveState>(
      bloc: _cubit,
      listenWhen: (SaveState a, SaveState b) => b.saved && !a.saved,
      listener: (BuildContext context, SaveState state) => context.pop(),
      builder: (BuildContext context, SaveState state) {
        return ChartEntryScaffold(
          title: "Today's plan",
          bottom: AppButton(
            label: 'Save plan',
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
                      'One item per line. Nothing is added for you. An empty plan stays "Not entered".',
                      style: AppTypography.regular(
                        fontSize: 13,
                        height: 1.4,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _text,
                      enabled: _loadError == null,
                      minLines: 8,
                      maxLines: 16,
                      keyboardType: TextInputType.multiline,
                      decoration: appInputDecoration(
                        context,
                        label: 'Plan for today',
                        hint:
                            'Continue IV diuresis\nRecheck creatinine this evening',
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
