import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/date_format.dart';
import 'package:round_ai/features/patient/bloc/add_source_cubit.dart';
import 'package:round_ai/features/patient/models/chart_source.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/app_input.dart';

/// Step 1 of chart data: paste source text, then read facts from it.
class AddSourceScreen extends StatelessWidget {
  const AddSourceScreen({required this.patientId, this.repository, super.key});

  final String patientId;
  final ChartDataRepository? repository;

  @override
  Widget build(BuildContext context) {
    final ChartDataRepository source =
        repository ?? InjectionContainer.instance.chartDataRepository;
    return BlocProvider<AddSourceCubit>(
      create: (_) => AddSourceCubit(source, patientId),
      child: _AddSourceForm(patientId: patientId),
    );
  }
}

class _AddSourceForm extends StatefulWidget {
  const _AddSourceForm({required this.patientId});

  final String patientId;

  @override
  State<_AddSourceForm> createState() => _AddSourceFormState();
}

class _AddSourceFormState extends State<_AddSourceForm> {
  final TextEditingController _text = TextEditingController();
  ChartSourceKind _kind = ChartSourceKind.progressNote;
  DateTime _time = DateTime.now();
  String? _validation;

  /// Whether the last tap asked to read facts. It decides where to go next.
  bool _extracted = true;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _run({required bool extract}) {
    _extracted = extract;
    _submit(extract: extract);
  }

  void _submit({required bool extract}) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_text.text.trim().isEmpty) {
      setState(() => _validation = 'Paste or type the chart text first.');
      return;
    }
    setState(() => _validation = null);
    context.read<AddSourceCubit>().submit(
      kind: _kind,
      time: _time,
      text: _text.text.trim(),
      extract: extract,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocConsumer<AddSourceCubit, AddSourceState>(
      listenWhen: (AddSourceState a, AddSourceState b) => b.done && !a.done,
      listener: (BuildContext context, AddSourceState state) {
        // Extracted: go on to review. Saved only: just go back.
        context.pop(
          _extracted ? AppRoutes.patientFactsPath(widget.patientId) : null,
        );
      },
      builder: (BuildContext context, AddSourceState state) {
        final String? message = _validation ?? state.error;
        final bool retrying = state.sourceId != null && state.error != null;
        return ChartEntryScaffold(
          title: 'Add source text',
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppButton(
                label: retrying
                    ? 'Try reading facts again'
                    : 'Save and read facts',
                loading: state.busy,
                onPressed: state.busy ? null : () => _run(extract: true),
              ),
              if (!retrying)
                TextButton(
                  onPressed: state.busy ? null : () => _run(extract: false),
                  child: const Text('Save without reading facts'),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Facts read from this text stay pending. AI only uses them after you confirm them.',
                style: AppTypography.regular(
                  fontSize: 13,
                  height: 1.4,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final ChartSourceKind kind in ChartSourceKind.values)
                    ChoiceChip(
                      label: Text(kind.label),
                      selected: _kind == kind,
                      onSelected: state.busy
                          ? null
                          : (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: state.busy
                    ? null
                    : () async {
                        final DateTime? picked = await pickDateTime(
                          context,
                          _time,
                        );
                        if (picked != null) setState(() => _time = picked);
                      },
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: Text('Source time · ${DateFormatter.dateTime(_time)}'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _text,
                enabled: !state.busy && state.sourceId == null,
                minLines: 8,
                maxLines: 16,
                keyboardType: TextInputType.multiline,
                decoration: appInputDecoration(
                  context,
                  label: 'Chart text',
                  hint: 'Paste a note, lab list or nursing entry',
                ),
              ),
              const FreeTextHint(),
              if (state.phase != SourcePhase.idle) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  state.phase == SourcePhase.saving
                      ? 'Saving the text…'
                      : 'Reading facts from the text…',
                  style: AppTypography.regular(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ],
              if (message != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  state.sourceId != null && state.error != null
                      ? 'The text is saved. $message'
                      : message,
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
