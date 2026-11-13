import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/date_format.dart';
import 'package:round_ai/features/ai/bloc/source_drawer_cubit.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/ai/widgets/evidence_card_view.dart';
import 'package:round_ai/features/patient/models/evidence_card.dart';
import 'package:round_ai/features/patient/models/fact.dart';

/// Opens the sources behind one claim. The repository is passed in because a
/// bottom sheet is not under the screen's providers.
Future<void> showSourceDrawer(
  BuildContext context, {
  required Claim claim,
  required AiRepository repository,
  List<EvidenceCard> evidence = const <EvidenceCard>[],
}) {
  final AppColors colors = AppColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.7,
        child: SourceDrawer(
          claim: claim,
          repository: repository,
          evidence: evidence,
        ),
      );
    },
  );
}

class SourceDrawer extends StatelessWidget {
  const SourceDrawer({
    required this.claim,
    required this.repository,
    this.evidence = const <EvidenceCard>[],
    super.key,
  });

  final Claim claim;
  final AiRepository repository;
  final List<EvidenceCard> evidence;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool chart = claim.label == ClaimLabel.fromChart;
    final List<EvidenceCard> cited = <EvidenceCard>[
      for (final EvidenceCard e in evidence)
        if (claim.evidenceIds.contains(e.id)) e,
    ];
    final bool noSource = claim.factIds.isEmpty && cited.isEmpty;
    return BlocProvider<SourceDrawerCubit>(
      create: (_) => SourceDrawerCubit(repository, claim.factIds)..load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: <Widget>[
          Text(
            'Source',
            style: AppTypography.bold(fontSize: 20, color: colors.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            claim.text,
            style: AppTypography.regular(
              height: 1.4,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            claim.labelText,
            style: AppTypography.medium(
              fontSize: 12,
              color: chart ? colors.success : colors.aiAccent,
            ),
          ),
          const SizedBox(height: 14),
          if (noSource)
            Text(
              chart
                  ? 'No source is attached to this statement. Check it '
                        'against the chart.'
                  : 'This is an AI interpretation, not a chart fact, so it '
                        'has no chart source. Check it against the chart.',
              style: AppTypography.regular(
                fontSize: 13,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
          BlocBuilder<SourceDrawerCubit, SourceDrawerState>(
            builder: (BuildContext context, SourceDrawerState state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final SourceEntry entry in state.entries)
                    _EntryView(entry: entry),
                ],
              );
            },
          ),
          for (final EvidenceCard card in cited) EvidenceCardView(card: card),
        ],
      ),
    );
  }
}

class _EntryView extends StatelessWidget {
  const _EntryView({required this.entry});

  final SourceEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final Widget body = switch (entry.load) {
      SourceLoad.loading => const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      SourceLoad.failed => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'The source could not be loaded. ${entry.message ?? ''}',
            style: AppTypography.regular(fontSize: 13, color: colors.error),
          ),
          TextButton(
            onPressed: () =>
                context.read<SourceDrawerCubit>().retry(entry.factId),
            child: const Text('Try again'),
          ),
        ],
      ),
      SourceLoad.ready => _Passage(source: entry.source!),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: body,
    );
  }
}

class _Passage extends StatelessWidget {
  const _Passage({required this.source});

  final SourcePassage source;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          source.passage.isEmpty ? 'Not entered' : '“${source.passage}”',
          style: AppTypography.regular(
            height: 1.4,
            color: source.passage.isEmpty ? colors.warning : colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          <String>[
            if (source.sourceTitle.isNotEmpty) source.sourceTitle,
            DateFormatter.dateTimeOrUnknown(source.sourceTime),
          ].join(' · '),
          style: AppTypography.regular(
            fontSize: 12,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
