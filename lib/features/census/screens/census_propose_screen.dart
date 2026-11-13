import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/census/models/census_intake.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/app_input.dart';

/// Review proposed census rows: edit, skip, then confirm.
class CensusProposeScreen extends StatefulWidget {
  const CensusProposeScreen({
    required this.proposal,
    this.repository,
    super.key,
  });

  final CensusIntakeProposal proposal;
  final CensusRepository? repository;

  @override
  State<CensusProposeScreen> createState() => _CensusProposeScreenState();
}

class _CensusProposeScreenState extends State<CensusProposeScreen> {
  late final List<ProposedCensusPatient> _rows =
      List<ProposedCensusPatient>.of(widget.proposal.patients);
  bool _busy = false;
  String? _error;

  int get _kept => _rows.where((ProposedCensusPatient r) => !r.skipped).length;

  Future<void> _confirm() async {
    if (_kept == 0) {
      setState(() => _error = 'Keep at least one patient, or go back.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final CensusRepository repo =
        widget.repository ?? InjectionContainer.instance.censusRepository;
    final Result<CensusConfirmResult> result = await repo.confirmCensus(
      widget.proposal.id,
      items: _rows,
    );
    if (!mounted) return;
    switch (result) {
      case Err(:final failure):
        setState(() {
          _busy = false;
          _error = failure.apiError.userMessage;
        });
      case Ok(:final value):
        setState(() => _busy = false);
        final String? factsId = value.firstFactsPatientId;
        if (factsId != null) {
          context.pop(AppRoutes.patientFactsPath(factsId));
        } else {
          context.pop(true);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return ChartEntryScaffold(
      title: 'Proposed patients',
      bottom: AppButton(
        label: _busy ? 'Confirming…' : 'Confirm selected ($_kept)',
        loading: _busy,
        onPressed: _busy ? null : _confirm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.proposal.note.isEmpty
                ? 'Proposed patients only. Nothing was added until you confirm.'
                : widget.proposal.note,
            style: AppTypography.regular(
              fontSize: 13,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          if (widget.proposal.sourceText.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text('Source text', style: AppTypography.semiBold(fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              widget.proposal.sourceText,
              style: AppTypography.regular(
                fontSize: 12,
                height: 1.4,
                color: colors.textMuted,
              ),
            ),
          ],
          if (widget.proposal.lowLegibilityLines.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Some lines were hard to read. Check the fields below.',
              style: AppTypography.regular(fontSize: 12, color: colors.warning),
            ),
          ],
          const SizedBox(height: 16),
          if (_rows.isEmpty)
            Text(
              'No patients were proposed. Try another photo or dictation.',
              style: AppTypography.regular(color: colors.textSecondary),
            )
          else
            for (int i = 0; i < _rows.length; i++)
              _ProposedCard(
                key: ValueKey<int>(_rows[i].index),
                patient: _rows[i],
                enabled: !_busy,
                onChanged: (ProposedCensusPatient next) {
                  setState(() => _rows[i] = next);
                },
              ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTypography.regular(fontSize: 13, color: colors.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProposedCard extends StatefulWidget {
  const _ProposedCard({
    required this.patient,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final ProposedCensusPatient patient;
  final bool enabled;
  final ValueChanged<ProposedCensusPatient> onChanged;

  @override
  State<_ProposedCard> createState() => _ProposedCardState();
}

class _ProposedCardState extends State<_ProposedCard> {
  late final TextEditingController _name = TextEditingController(
    text: widget.patient.displayName,
  );
  late final TextEditingController _room = TextEditingController(
    text: widget.patient.room,
  );
  late final TextEditingController _age = TextEditingController(
    text: widget.patient.ageBand,
  );
  late final TextEditingController _sex = TextEditingController(
    text: widget.patient.sex,
  );
  late final TextEditingController _reason = TextEditingController(
    text: widget.patient.oneLineReason,
  );
  late final TextEditingController _source = TextEditingController(
    text: widget.patient.sourceText,
  );

  @override
  void dispose() {
    _name.dispose();
    _room.dispose();
    _age.dispose();
    _sex.dispose();
    _reason.dispose();
    _source.dispose();
    super.dispose();
  }

  void _emit({bool? skipped}) {
    widget.onChanged(
      widget.patient.copyWith(
        displayName: _name.text,
        room: _room.text,
        ageBand: _age.text,
        sex: _sex.text,
        oneLineReason: _reason.text,
        sourceText: _source.text,
        skipped: skipped,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool skipped = widget.patient.skipped;
    final bool enabled = widget.enabled && !skipped;
    return Opacity(
      opacity: skipped ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Row ${widget.patient.index + 1}',
                    style: AppTypography.semiBold(fontSize: 13),
                  ),
                ),
                FilterChip(
                  label: Text(skipped ? 'Skipped' : 'Keep'),
                  selected: !skipped,
                  onSelected: widget.enabled
                      ? (bool keep) => _emit(skipped: !keep)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              enabled: enabled,
              controller: _name,
              onChanged: (_) => _emit(),
              decoration: appInputDecoration(context, label: 'Name'),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    enabled: enabled,
                    controller: _room,
                    onChanged: (_) => _emit(),
                    decoration: appInputDecoration(context, label: 'Room'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    enabled: enabled,
                    controller: _age,
                    onChanged: (_) => _emit(),
                    decoration: appInputDecoration(context, label: 'Age band'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    enabled: enabled,
                    controller: _sex,
                    onChanged: (_) => _emit(),
                    decoration: appInputDecoration(context, label: 'Sex'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              enabled: enabled,
              controller: _reason,
              onChanged: (_) => _emit(),
              minLines: 1,
              maxLines: 3,
              decoration: appInputDecoration(
                context,
                label: 'One-line reason',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              enabled: enabled,
              controller: _source,
              onChanged: (_) => _emit(),
              minLines: 2,
              maxLines: 4,
              decoration: appInputDecoration(context, label: 'Source text'),
            ),
          ],
        ),
      ),
    );
  }
}
