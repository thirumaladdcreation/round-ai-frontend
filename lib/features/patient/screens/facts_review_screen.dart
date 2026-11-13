import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/date_format.dart';
import 'package:round_ai/features/patient/bloc/facts_review_bloc.dart';
import 'package:round_ai/features/patient/models/fact.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/shared/widgets/app_button.dart';
import 'package:round_ai/shared/widgets/retry_view.dart';
import 'package:round_ai/shared/widgets/skeleton.dart';

/// Step 2 of chart data: confirm or reject each fact read from the sources.
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
      child: const _FactsReviewView(),
    );
  }
}

class _FactsReviewView extends StatelessWidget {
  const _FactsReviewView();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocBuilder<FactsReviewBloc, FactsReviewState>(
      builder: (BuildContext context, FactsReviewState state) {
        if (state.loading && state.facts.isEmpty) {
          return const ChartEntryScaffold(
            title: 'Review chart facts',
            child: SkeletonColumn(count: 3),
          );
        }
        if (state.facts.isEmpty && state.error != null) {
          return ChartEntryScaffold(
            title: 'Review chart facts',
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
                'These facts were read from your source text. Check each one '
                'against the passage. Only confirmed facts are used by AI.',
                style: AppTypography.regular(
                  fontSize: 13,
                  height: 1.4,
                  color: colors.textSecondary,
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
              const SizedBox(height: 12),
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
                  controlAffinity: ListTileControlAffinity.leading,
                  value: state.allSelected,
                  onChanged: state.busy
                      ? null
                      : (_) => context.read<FactsReviewBloc>().add(
                          const AllFactsToggled(),
                        ),
                  title: Text(
                    'Select all (${state.facts.length})',
                    style: AppTypography.medium(fontSize: 14),
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
    final String value = <String>[
      fact.value,
      if (fact.unit != null) fact.unit!,
    ].join(' ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? colors.primary : colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Checkbox(
            value: selected,
            onChanged: busy ? null : (_) => bloc.add(FactToggled(fact.id)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    fact.name,
                    style: AppTypography.semiBold(
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.isEmpty ? 'Not entered' : value,
                    style: AppTypography.regular(
                      fontSize: 14,
                      color: value.isEmpty
                          ? colors.warning
                          : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormatter.dateTimeOrUnknown(fact.eventTime),
                    style: AppTypography.regular(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                  if (fact.passage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.inputFill,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '“${fact.passage}”',
                        style: AppTypography.regular(
                          fontSize: 12,
                          height: 1.35,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => bloc.add(
                                FactsDecided(confirm: false, factId: fact.id),
                              ),
                        child: const Text('Reject'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => bloc.add(
                                FactsDecided(confirm: true, factId: fact.id),
                              ),
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
