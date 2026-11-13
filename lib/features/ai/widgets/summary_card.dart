import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/date_format.dart';
import 'package:round_ai/features/ai/bloc/summary_cubit.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/models/summary_content.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/ai/widgets/claim_tile.dart';
import 'package:round_ai/features/ai/widgets/placeholder_text.dart';
import 'package:round_ai/features/ai/widgets/source_drawer.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';

const String aiOffMessage = 'AI is temporarily off. Manual entry still works.';

/// The AI patient summary on the overview, on the real backend.
///
/// It shows the saved summary, or a Generate button. Nothing here is applied
/// to the chart: the clinician reads it, then marks that version reviewed.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    required this.patientId,
    required this.revision,
    required this.aiOff,
    required this.onChanged,
    this.repository,
    super.key,
  });

  final String patientId;

  /// Chart revision. When it changes the saved summary is read again, so a
  /// summary made before the change shows as Outdated.
  final int revision;
  final bool aiOff;

  /// Called after a summary is generated or reviewed, so the screen reloads.
  final VoidCallback onChanged;
  final AiRepository? repository;

  @override
  Widget build(BuildContext context) {
    final AiRepository source = repository ?? context.read<AiRepository>();
    return BlocProvider<SummaryCubit>(
      create: (_) => SummaryCubit(source, patientId)..load(),
      child: _SummaryView(
        patientId: patientId,
        revision: revision,
        aiOff: aiOff,
        repository: source,
        onChanged: onChanged,
      ),
    );
  }
}

class _SummaryView extends StatefulWidget {
  const _SummaryView({
    required this.patientId,
    required this.revision,
    required this.aiOff,
    required this.repository,
    required this.onChanged,
  });

  final String patientId;
  final int revision;
  final bool aiOff;
  final AiRepository repository;
  final VoidCallback onChanged;

  @override
  State<_SummaryView> createState() => _SummaryViewState();
}

class _SummaryViewState extends State<_SummaryView> {
  @override
  void didUpdateWidget(_SummaryView old) {
    super.didUpdateWidget(old);
    if (old.revision != widget.revision) {
      context.read<SummaryCubit>().load();
    }
  }

  Future<void> _reviewFacts() async {
    await context.push<Object>(AppRoutes.patientFactsPath(widget.patientId));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocConsumer<SummaryCubit, SummaryCardState>(
      listenWhen: (SummaryCardState a, SummaryCardState b) =>
          a.changes != b.changes,
      listener: (BuildContext context, SummaryCardState state) =>
          widget.onChanged(),
      builder: (BuildContext context, SummaryCardState state) {
        final SummaryCubit cubit = context.read<SummaryCubit>();
        final AiEnvelope? envelope = state.envelope;
        final bool draft = envelope != null && !envelope.isReviewed;
        final Set<String> marked = state.markedSections;
        final ApiError? error = state.error;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.aiCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.aiBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.auto_awesome, size: 16, color: colors.aiAccent),
                  const SizedBox(width: 6),
                  Text(
                    'AI Patient Summary',
                    style: AppTypography.semiBold(
                      color: colors.aiAccent,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (draft) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'AI draft · review required',
                  style: AppTypography.medium(
                    color: colors.aiAccent,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  AiStateChip(state: state.aiState),
                  if (envelope?.createdAt != null)
                    Text(
                      'Made ${DateFormatter.dateTime(envelope!.createdAt!)}',
                      style: AppTypography.regular(
                        color: colors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.phase == SummaryPhase.loading &&
                  envelope == null) ...<Widget>[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ] else ...<Widget>[
                if (envelope == null)
                  Text(
                    'No summary yet. A summary is built only from chart facts '
                    'you have confirmed.',
                    style: AppTypography.regular(
                      height: 1.45,
                      color: colors.textPrimary,
                    ),
                  )
                else
                  SummaryBody(
                    envelope: envelope,
                    content: state.content!,
                    marked: marked,
                    repository: widget.repository,
                  ),
              ],
              if (state.generating) ...<Widget>[
                const SizedBox(height: 8),
                _Generating(onCancel: cubit.cancel),
              ],
              if (error != null && !state.generating) ...<Widget>[
                const SizedBox(height: 8),
                _ErrorBox(
                  error: error,
                  // A failed read is read again. A failed generation is
                  // generated again with the same Idempotency-Key.
                  onRetry: error.isRetryable
                      ? (state.errorFromLoad ? cubit.load : cubit.generate)
                      : null,
                  onReviewFacts: error.kind == ApiErrorKind.noReviewedFacts
                      ? _reviewFacts
                      : null,
                ),
              ],
              if (state.reviewError != null) ...<Widget>[
                const SizedBox(height: 8),
                _ErrorBox(
                  error: state.reviewError!,
                  sections: state.flaggedSections.length,
                ),
              ],
              if (widget.aiOff) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  aiOffMessage,
                  style: AppTypography.regular(
                    fontSize: 12,
                    color: colors.critical,
                  ),
                ),
              ],
              if (!state.generating &&
                  !(state.phase == SummaryPhase.loading &&
                      envelope == null)) ...<Widget>[
                const SizedBox(height: 8),
                _Actions(state: state, aiOff: widget.aiOff),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.state, required this.aiOff});

  final SummaryCardState state;
  final bool aiOff;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final SummaryCubit cubit = context.read<SummaryCubit>();
    final AiEnvelope? envelope = state.envelope;
    final String? blocked = state.reviewBlockedReason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed: aiOff ? null : cubit.generate,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(envelope == null ? 'Generate summary' : 'Regenerate'),
            ),
            if (envelope != null && !envelope.isReviewed)
              FilledButton.icon(
                onPressed: state.canMarkReviewed ? cubit.markReviewed : null,
                icon: state.reviewing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Mark reviewed'),
              ),
          ],
        ),
        if (blocked != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            blocked,
            style: AppTypography.regular(fontSize: 12, color: colors.warning),
          ),
        ],
      ],
    );
  }
}

class _Generating extends StatelessWidget {
  const _Generating({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Generating the summary. This can take up to a minute.',
            style: AppTypography.regular(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
        ),
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({
    required this.error,
    this.sections = 0,
    this.onRetry,
    this.onReviewFacts,
  });

  final ApiError error;
  final int sections;
  final VoidCallback? onRetry;
  final VoidCallback? onReviewFacts;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.criticalBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            error.userMessage,
            style: AppTypography.regular(fontSize: 13, color: colors.critical),
          ),
          if (sections > 0)
            Text(
              sections == 1
                  ? '1 section is marked below.'
                  : '$sections sections are marked below.',
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.critical,
              ),
            ),
          if (onReviewFacts != null)
            TextButton(
              onPressed: onReviewFacts,
              child: const Text('Review chart facts first'),
            ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// What a saved AI summary shows: notices, claims with sources, missing
/// information and conflicts. Sign-out reuses it.
class SummaryBody extends StatelessWidget {
  const SummaryBody({
    super.key,
    required this.envelope,
    required this.content,
    required this.marked,
    required this.repository,
  });

  final AiEnvelope envelope;
  final SummaryContent content;
  final Set<String> marked;
  final AiRepository repository;

  void _open(BuildContext context, Claim claim) {
    showSourceDrawer(context, claim: claim, repository: repository);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final TextStyle small = AppTypography.regular(
      fontSize: 12,
      height: 1.4,
      color: colors.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (envelope.outdated)
          _Notice(
            color: colors.warningSoft,
            textColor: colors.warning,
            text:
                'Outdated. The chart changed after this summary was made. '
                'You can still read it. Regenerate to update it.',
          ),
        if (envelope.isPartial)
          _Notice(
            color: colors.warningSoft,
            textColor: colors.warning,
            text: envelope.validationIssues.isEmpty
                ? 'Partial result. Some parts were withheld by validation.'
                : 'Partial result. ${envelope.validationIssues.length} '
                      '${envelope.validationIssues.length == 1 ? 'part was' : 'parts were'} '
                      'withheld by validation.',
          ),
        if (content.truncated)
          _Notice(
            color: colors.warningSoft,
            textColor: colors.warning,
            text:
                'The chart was long, so part of it was left out of this '
                'summary. Check the chart for anything missing.',
          ),
        if (content.oneLiner != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Marked(
              marked: marked.contains('one_liner'),
              child: ClaimTile(
                claim: content.oneLiner!,
                bold: true,
                onTap: () => _open(context, content.oneLiner!),
              ),
            ),
          ),
        for (final SummarySection section in content.sections)
          _SectionView(
            section: section,
            marked: marked.contains(section.key),
            onClaim: (Claim c) => _open(context, c),
          ),
        if (content.missingInformation.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Missing information',
            style: AppTypography.semiBold(
              fontSize: 13,
              color: colors.textPrimary,
            ),
          ),
          for (final String item in content.missingInformation)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.report_gmailerrorred_rounded,
                    size: 16,
                    color: colors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$item · Not entered',
                      style: AppTypography.regular(
                        fontSize: 13,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (content.conflicts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            'Conflicts in the chart',
            style: AppTypography.semiBold(
              fontSize: 13,
              color: colors.textPrimary,
            ),
          ),
          for (final InsightItem item in content.conflicts)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: PlaceholderText(
                '• ${item.label.isEmpty ? '' : '${item.label}: '}${item.text}',
                style: small.copyWith(color: colors.textPrimary),
              ),
            ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({
    required this.section,
    required this.marked,
    required this.onClaim,
  });

  final SummarySection section;
  final bool marked;
  final void Function(Claim claim) onClaim;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return _Marked(
      marked: marked,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            section.title,
            style: AppTypography.semiBold(
              fontSize: 13,
              color: colors.textPrimary,
            ),
          ),
          if (section.claims.isNotEmpty)
            for (final Claim claim in section.claims)
              ClaimTile(claim: claim, onTap: () => onClaim(claim))
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: PlaceholderText(
                section.text,
                style: AppTypography.regular(
                  height: 1.4,
                  color: colors.textPrimary,
                ),
              ),
            ),
          if (marked)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Needs attention before this can be reviewed.',
                style: AppTypography.medium(
                  fontSize: 11,
                  color: colors.warning,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A frame around a section that still has missing text or a flag.
class _Marked extends StatelessWidget {
  const _Marked({required this.marked, required this.child});

  final bool marked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: marked ? const EdgeInsets.all(8) : EdgeInsets.zero,
      decoration: marked
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.warning),
            )
          : null,
      child: child,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.color,
    required this.textColor,
    required this.text,
  });

  final Color color;
  final Color textColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: AppTypography.regular(
          fontSize: 12,
          height: 1.4,
          color: textColor,
        ),
      ),
    );
  }
}
