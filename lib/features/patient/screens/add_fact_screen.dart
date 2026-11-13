import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/date_format.dart';
import 'package:round_ai/features/patient/bloc/save_cubit.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/app_input.dart';

/// Manual fact entry, for something the clinician knows and no source says.
class AddFactScreen extends StatelessWidget {
  const AddFactScreen({required this.patientId, this.repository, super.key});

  final String patientId;
  final ChartDataRepository? repository;

  @override
  Widget build(BuildContext context) {
    final ChartDataRepository source =
        repository ?? InjectionContainer.instance.chartDataRepository;
    return BlocProvider<ManualFactCubit>(
      create: (_) => ManualFactCubit(source, patientId),
      child: const _AddFactForm(),
    );
  }
}

class _AddFactForm extends StatefulWidget {
  const _AddFactForm();

  @override
  State<_AddFactForm> createState() => _AddFactFormState();
}

class _AddFactFormState extends State<_AddFactForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _value = TextEditingController();
  final TextEditingController _unit = TextEditingController();
  DateTime? _time;
  String? _validation;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _unit.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _value.text.trim().isEmpty) {
      setState(() => _validation = 'Enter what it is and its value.');
      return;
    }
    setState(() => _validation = null);
    context.read<ManualFactCubit>().save(
      NewFact(
        name: _name.text.trim(),
        value: _value.text.trim(),
        unit: _unit.text.trim(),
        eventTime: _time,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocConsumer<ManualFactCubit, SaveState>(
      listenWhen: (SaveState a, SaveState b) => b.saved && !a.saved,
      listener: (BuildContext context, SaveState state) {
        // Hand back the review screen, so the new fact can be confirmed.
        context.pop(
          AppRoutes.patientFactsPath(context.read<ManualFactCubit>().patientId),
        );
      },
      builder: (BuildContext context, SaveState state) {
        final String? message = _validation ?? state.error;
        return ChartEntryScaffold(
          title: 'Add a fact',
          bottom: AppButton(
            label: 'Save fact',
            loading: state.saving,
            onPressed: state.saving ? null : _submit,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'The fact is saved as pending. Confirm it on the review screen before AI can use it.',
                style: AppTypography.regular(
                  fontSize: 13,
                  height: 1.4,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: appInputDecoration(
                  context,
                  label: 'What',
                  hint: 'Creatinine, O2 flow, urine output',
                ),
              ),
              const FreeTextHint(),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _value,
                      decoration: appInputDecoration(context, label: 'Value'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _unit,
                      decoration: appInputDecoration(
                        context,
                        label: 'Unit',
                        hint: 'optional',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final DateTime? picked = await pickDateTime(
                          context,
                          _time ?? DateTime.now(),
                        );
                        if (picked != null) setState(() => _time = picked);
                      },
                      icon: const Icon(Icons.schedule_rounded, size: 18),
                      label: Text(
                        'When · ${DateFormatter.dateTimeOrUnknown(_time)}',
                      ),
                    ),
                  ),
                  if (_time != null)
                    IconButton(
                      tooltip: 'Clear time',
                      onPressed: () => setState(() => _time = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  message,
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
