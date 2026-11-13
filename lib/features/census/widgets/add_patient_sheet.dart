import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/census/bloc/census_bloc.dart';
import 'package:round_ai/features/census/bloc/census_event.dart';
import 'package:round_ai/features/census/bloc/census_state.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/app_input.dart';

Future<void> showAddPatientSheet(BuildContext context) {
  final CensusBloc bloc = context.read<CensusBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.of(context).surface,
    builder: (BuildContext sheetContext) => BlocProvider<CensusBloc>.value(
      value: bloc,
      child: const AddPatientSheet(),
    ),
  );
}

class AddPatientSheet extends StatefulWidget {
  const AddPatientSheet({this.teamId, super.key});

  /// Defaults to the selected team.
  final String? teamId;

  @override
  State<AddPatientSheet> createState() => _AddPatientSheetState();
}

class _AddPatientSheetState extends State<AddPatientSheet> {
  static const List<String> ageBands = <String>[
    '18-29',
    '30-39',
    '40-49',
    '50-59',
    '60-69',
    '70-79',
    '80-89',
    '90+',
  ];
  static const Map<String, String> sexes = <String, String>{
    'F': 'Female',
    'M': 'Male',
    'O': 'Other',
  };

  final TextEditingController _name = TextEditingController();
  final TextEditingController _room = TextEditingController();
  String? _ageBand;
  String? _sex;
  String? _validation;

  @override
  void dispose() {
    _name.dispose();
    _room.dispose();
    super.dispose();
  }

  void _submit() {
    final String? teamId =
        widget.teamId ?? InjectionContainer.instance.appStorage.selectedTeamId;
    if (teamId == null) {
      setState(() => _validation = 'Select a team first.');
      return;
    }
    if (_name.text.trim().isEmpty ||
        _room.text.trim().isEmpty ||
        _ageBand == null ||
        _sex == null) {
      setState(() => _validation = 'Fill in every field.');
      return;
    }
    setState(() => _validation = null);
    context.read<CensusBloc>().add(
      PatientAddRequested(
        NewPatient(
          teamId: teamId,
          displayName: _name.text.trim(),
          room: _room.text.trim(),
          ageBand: _ageBand!,
          sex: _sex!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocConsumer<CensusBloc, CensusState>(
      listenWhen: (CensusState a, CensusState b) =>
          b.addedCount != a.addedCount,
      listener: (BuildContext context, CensusState state) =>
          Navigator.of(context).pop(),
      builder: (BuildContext context, CensusState state) {
        final String? message = _validation ?? state.addError;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Add patient',
                  style: AppTypography.bold(
                    fontSize: 20,
                    color: colors.textPrimary,
                  ),
                ),
                if (!AppEnvironment.type.isProduction) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Development build: use fictional names only.',
                    style: AppTypography.regular(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: appInputDecoration(
                    context,
                    label: 'Display name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _room,
                  decoration: appInputDecoration(
                    context,
                    label: 'Room',
                    hint: '509A',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _ageBand,
                  decoration: appInputDecoration(context, label: 'Age band'),
                  items: <DropdownMenuItem<String>>[
                    for (final String band in ageBands)
                      DropdownMenuItem<String>(value: band, child: Text(band)),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _ageBand = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _sex,
                  decoration: appInputDecoration(context, label: 'Sex'),
                  items: <DropdownMenuItem<String>>[
                    for (final MapEntry<String, String> e in sexes.entries)
                      DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      ),
                  ],
                  onChanged: (String? value) => setState(() => _sex = value),
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
                const SizedBox(height: 16),
                AppButton(
                  label: 'Add patient',
                  loading: state.adding,
                  onPressed: state.adding ? null : _submit,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
