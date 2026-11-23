import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/date_format.dart';
import 'package:round_ai/features/patient/bloc/facts_review_bloc.dart';
import 'package:round_ai/features/patient/models/fact.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository.dart';
import 'package:round_ai/features/patient/utils/fact_display.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/retry_view.dart';
import 'package:round_ai/shared/widgets/skeleton.dart';

/// Confirm or reject extracted facts with source passages in one screen.
class FactsReviewScreen extends StatelessWidget {
  const FactsReviewScreen({
    required this.patientId,
    this.repository,
    super.key,
  });

  final String patientId;
  final ChartDataRepository? repository;

  @override
  Widget build(BuildContext context) {
    final ChartDataRepository source =
        repository ?? InjectionContainer.instance.chartDataRepository;
    return BlocProvider<FactsReviewBloc>(
      create: (_) =>
          FactsReviewBloc(source, patientId)..add(const FactsRequested()),
      child: _FactsReviewView(patientId: patientId),
    );
  }
}

class _FactsReviewView extends StatefulWidget {
  const _FactsReviewView({required this.patientId});

  final String patientId;

  @override
  State<_FactsReviewView> createState() => _FactsReviewViewState();
}

class _FactsReviewViewState extends State<_FactsReviewView> {
  String _patientName = '';
  String _room = '';

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    try {
      final Result<PatientDetail> result = await InjectionContainer
          .instance
          .patientRepository
          .loadDetail(widget.patientId);
      if (!mounted) return;
      switch (result) {
        case Ok<PatientDetail>(:final value):
          setState(() {
            _patientName = value.patient.displayName;
            _room = value.patient.room;
          });
        case Err<PatientDetail>():
          break;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocBuilder<FactsReviewBloc, FactsReviewState>(
      builder: (BuildContext context, FactsReviewState state) {
        if (state.loading && state.facts.isEmpty) {
          return ChartEntryScaffold(
            title: 'Review chart facts',
            patientName: _patientName,
            room: _room,
            child: const SkeletonColumn(count: 3),
          );
        }
        if (state.facts.isEmpty && state.error != null) {
          return ChartEntryScaffold(
            title: 'Review chart facts',
            patientName: _patientName,
            room: _room,
            child: SizedBox(
              height: 360,
              child: RetryView(
                title: 'Facts could not be loaded.',
                message: state.error!,
                onRetry: () =>
                    context.read<FactsReviewBloc>().add(const FactsRequested()),
              ),
            ),
          );
        }
        final int picked = state.selected.length;
        return ChartEntryScaffold(
          title: 'Review chart facts',
          patientName: _patientName,
          room: _room,
          onRefresh: () {
            final Completer<void> done = Completer<void>();
            context.read<FactsReviewBloc>().add(FactsRequested(done: done));
            return done.future;
          },
          bottom: state.facts.isEmpty
              ? null
              : Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton(
                        label: picked == 0 ? 'Reject' : 'Reject ($picked)',
                        variant: AppButtonVariant.outline,
                        onPressed: picked == 0 || state.busy
                            ? null
                            : () => context.read<FactsReviewBloc>().add(
                                const FactsDecided(confirm: false),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: picked == 0 ? 'Confirm' : 'Confirm ($picked)',
                        loading: state.busy,
                        onPressed: picked == 0 || state.busy
                            ? null
                            : () => context.read<FactsReviewBloc>().add(
                                const FactsDecided(confirm: true),
                              ),
                      ),
                    ),
                  ],
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Only confirmed facts are used by AI. Check each fact against '
                'its source passage. Keep SpO₂ context (room air vs '
                'supplemental O₂).',
                style: AppTypography.regular(
                  fontSize: 13,
                  height: 1.35,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB7E6EC)),
                ),
                child: Text(
                  'Dictation tip: if your note includes an Assessment and Plan, '
                  'you’ll be offered to save it on the patient page — no need '
                  'to type it twice.',
                  style: AppTypography.regular(
                    fontSize: 12,
                    height: 1.35,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (state.error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  state.lastFailed > 0
                      ? '${state.lastFailed} could not be updated. ${state.error}'
                      : state.error!,
                  style: AppTypography.regular(
                    fontSize: 13,
                    color: colors.error,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _IntegrityAndProposals(patientId: widget.patientId),
              if (state.facts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Center(
                    child: Text(
                      state.lastDecided > 0
                          ? 'All done. No facts are waiting for review.'
                          : 'No facts are waiting for review.',
                      textAlign: TextAlign.center,
                      style: AppTypography.regular(color: colors.textSecondary),
                    ),
                  ),
                )
              else ...<Widget>[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: state.allSelected,
                  onChanged: state.busy
                      ? null
                      : (_) => context.read<FactsReviewBloc>().add(
                          const AllFactsToggled(),
                        ),
                  title: Text(
                    'Select all (${state.facts.length})',
                    style: AppTypography.medium(fontSize: 13),
                  ),
                  subtitle: Text(
                    'Use Confirm / Reject below for bulk review.',
                    style: AppTypography.regular(
                      fontSize: 11,
                      color: colors.textMuted,
                    ),
                  ),
                ),
                for (final Fact fact in state.facts)
                  FactReviewCard(
                    fact: fact,
                    selected: state.selected.contains(fact.id),
                    busy: state.busy,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class FactReviewCard extends StatelessWidget {
  const FactReviewCard({
    required this.fact,
    required this.selected,
    required this.busy,
    super.key,
  });

  final Fact fact;
  final bool selected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final FactsReviewBloc bloc = context.read<FactsReviewBloc>();
    final String value = factValueLine(fact);
    final String? passage = fact.passage?.trim();
    final bool o2 = factNeedsOxygenContext(fact);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(2, 6, 10, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? colors.primary : colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Checkbox(
            visualDensity: VisualDensity.compact,
            value: selected,
            onChanged: busy ? null : (_) => bloc.add(FactToggled(fact.id)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        fact.name,
                        style: AppTypography.semiBold(
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      DateFormatter.dateTimeOrUnknown(fact.eventTime),
                      style: AppTypography.regular(
                        fontSize: 11,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.regular(
                    fontSize: 13,
                    color: value == 'Not entered'
                        ? colors.warning
                        : colors.textPrimary,
                  ),
                ),
                if ((fact.qualifier ?? '').trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F3FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      fact.qualifier!.trim(),
                      style: AppTypography.semiBold(
                        fontSize: 11,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
                if (o2 &&
                    (fact.qualifier ?? '').trim().isEmpty &&
                    oxygenContextHint(fact).isEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    'Add room air vs supplemental O₂ if missing from the source.',
                    style: AppTypography.regular(
                      fontSize: 11,
                      color: colors.warning,
                    ),
                  ),
                ],
                if (fact.warnings.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  for (final FactWarning w in fact.warnings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        w.message,
                        style: AppTypography.regular(
                          fontSize: 11,
                          color: colors.warning,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.inputFill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Source passage',
                        style: AppTypography.semiBold(
                          fontSize: 10,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        passage == null || passage.isEmpty
                            ? 'No supporting passage stored for this fact.'
                            : '“$passage”',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.regular(
                          fontSize: 12,
                          height: 1.35,
                          color: colors.textSecondary,
                        ),
                      ),
                      if (passage != null && passage.length > 120)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (BuildContext ctx) => AlertDialog(
                                  title: const Text('Source passage'),
                                  content: SingleChildScrollView(
                                    child: Text('“$passage”'),
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('Expand'),
                          ),
                        ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 0,
                    children: <Widget>[
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: busy
                            ? null
                            : () => _editFact(context, fact),
                        child: const Text('Edit'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: busy
                            ? null
                            : () => bloc.add(
                                FactsDecided(confirm: false, factId: fact.id),
                              ),
                        child: const Text('Reject'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: busy
                            ? null
                            : () => bloc.add(
                                FactsDecided(confirm: true, factId: fact.id),
                              ),
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _editFact(BuildContext context, Fact fact) async {
  final TextEditingController name = TextEditingController(text: fact.name);
  final TextEditingController value = TextEditingController(text: fact.value);
  final TextEditingController qualifier = TextEditingController(
    text: fact.qualifier ?? '',
  );
  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: const Text('Edit fact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            TextField(
              controller: value,
              decoration: const InputDecoration(labelText: 'Value'),
            ),
            TextField(
              controller: qualifier,
              decoration: const InputDecoration(
                labelText: 'Qualifier (must appear in passage)',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
  if (saved != true || !context.mounted) return;
  try {
    final ChartDataRepository repo =
        InjectionContainer.instance.chartDataRepository;
    final Result<Fact> result = await repo.editFact(
      fact.id,
      name: name.text.trim(),
      value: value.text.trim(),
      qualifier: qualifier.text.trim(),
    );
    if (!context.mounted) return;
    switch (result) {
      case Ok<Fact>():
        context.read<FactsReviewBloc>().add(const FactsRequested());
      case Err<Fact>(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
    }
  } catch (_) {}
}

/// Identity/date warnings + A&P proposals from the latest extract.
class _IntegrityAndProposals extends StatefulWidget {
  const _IntegrityAndProposals({required this.patientId});

  final String patientId;

  @override
  State<_IntegrityAndProposals> createState() => _IntegrityAndProposalsState();
}

class _IntegrityAndProposalsState extends State<_IntegrityAndProposals> {
  List<FactWarning> _warnings = const <FactWarning>[];
  List<PlanProposal> _proposals = const <PlanProposal>[];
  final Set<int> _selected = <int>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ChartDataRepository repo =
          InjectionContainer.instance.chartDataRepository;
      final Result<List<FactWarning>> w = await repo.extractWarnings(
        widget.patientId,
      );
      final Result<List<PlanProposal>> p = await repo.planProposals(
        widget.patientId,
      );
      if (!mounted) return;
      setState(() {
        if (w case Ok<List<FactWarning>>(:final value)) _warnings = value;
        if (p case Ok<List<PlanProposal>>(:final value)) {
          _proposals = value;
          _selected
            ..clear()
            ..addAll(
              List<int>.generate(value.length, (int i) => i),
            );
        }
      });
    } catch (_) {}
  }

  Future<void> _accept() async {
    final List<PlanProposal> picked = <PlanProposal>[
      for (final int i in _selected)
        if (i >= 0 && i < _proposals.length) _proposals[i],
    ];
    if (picked.isEmpty) return;
    setState(() => _busy = true);
    try {
      final Result<void> result = await InjectionContainer
          .instance
          .chartDataRepository
          .acceptPlanProposals(widget.patientId, picked);
      if (!mounted) return;
      setState(() => _busy = false);
      switch (result) {
        case Ok<void>():
          setState(() {
            _proposals = const <PlanProposal>[];
            _selected.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Assessment and Plan proposals saved. Review them on the patient page.',
              ),
            ),
          );
        case Err<void>(:final failure):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    if (_warnings.isEmpty && _proposals.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final FactWarning w in _warnings)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.criticalBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              w.message,
              style: AppTypography.regular(
                fontSize: 12,
                height: 1.35,
                color: colors.critical,
              ),
            ),
          ),
        if (_proposals.isNotEmpty) ...<Widget>[
          Text(
            'Assessment and Plan from dictation',
            style: AppTypography.semiBold(
              fontSize: 14,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Confirm once to pre-fill today’s plan. New problems are marked '
            '“new, not confirmed”.',
            style: AppTypography.regular(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < _proposals.length; i++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _selected.contains(i),
              onChanged: _busy
                  ? null
                  : (bool? v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(i);
                        } else {
                          _selected.remove(i);
                        }
                      });
                    },
              title: Text(
                _proposals[i].title.isEmpty
                    ? 'General'
                    : _proposals[i].title,
                style: AppTypography.semiBold(fontSize: 13),
              ),
              subtitle: Text(
                _proposals[i].planText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.regular(fontSize: 12),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _busy || _selected.isEmpty ? null : _accept,
              child: Text(
                _busy ? 'Saving…' : 'Save selected to Assessment and Plan',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
