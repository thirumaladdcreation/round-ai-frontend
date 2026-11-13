import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/date_format.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/learning/bloc/mcq_queue_cubit.dart';
import 'package:round_ai/features/learning/models/mcq.dart';
import 'package:round_ai/features/learning/models/mcq_draft.dart';
import 'package:round_ai/features/learning/repository/teach_repository.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/shared/widgets/ai_error_box.dart';
import 'package:round_ai/shared/widgets/retry_view.dart';
import 'package:round_ai/shared/widgets/skeleton.dart';

/// Questions made for this patient that nobody has reviewed yet. A reviewer
/// reads the whole question and the key, then taps Mark reviewed.
class TeachQueueScreen extends StatelessWidget {
  const TeachQueueScreen({
    required this.patientId,
    this.teachRepository,
    this.aiRepository,
    super.key,
  });

  final String patientId;
  final TeachRepository? teachRepository;
  final AiRepository? aiRepository;

  @override
  Widget build(BuildContext context) {
    final InjectionContainer di = InjectionContainer.instance;
    return BlocProvider<McqQueueCubit>(
      create: (_) => McqQueueCubit(
        teachRepository ?? di.teachRepository,
        aiRepository ?? di.aiRepository,
        patientId,
      )..load(),
      child: const _QueueView(),
    );
  }
}

class _QueueView extends StatelessWidget {
  const _QueueView();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocBuilder<McqQueueCubit, McqQueueState>(
      builder: (BuildContext context, McqQueueState state) {
        final McqQueueCubit cubit = context.read<McqQueueCubit>();
        return ChartEntryScaffold(
          title: 'Review queue',
          onRefresh: cubit.load,
          child: state.loading && state.items.isEmpty
              ? const SkeletonColumn(count: 2)
              : state.error != null
              ? SizedBox(
                  height: 280,
                  child: RetryView(
                    title: 'The review queue could not be loaded.',
                    message: state.error!.userMessage,
                    onRetry: cubit.load,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'AI-generated questions are not used for teaching '
                      'until they are reviewed.',
                      style: AppTypography.regular(
                        fontSize: 13,
                        height: 1.4,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (state.reviewError != null)
                      AiErrorBox(error: state.reviewError!),
                    if (state.items.isEmpty)
                      Text(
                        'No questions are waiting for review.',
                        style: AppTypography.regular(
                          color: colors.textSecondary,
                        ),
                      )
                    else
                      for (final McqDraft draft in state.items)
                        _QueueItem(
                          draft: draft,
                          busy: state.reviewingId == draft.envelope.artifactId,
                          locked: state.reviewingId != null,
                        ),
                  ],
                ),
        );
      },
    );
  }
}

class _QueueItem extends StatelessWidget {
  const _QueueItem({
    required this.draft,
    required this.busy,
    required this.locked,
  });

  final McqDraft draft;
  final bool busy;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final McqQueueCubit cubit = context.read<McqQueueCubit>();
    final Mcq q = draft.mcq;
    final DateTime? made = draft.envelope.createdAt;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'AI-generated, not yet reviewed',
            style: AppTypography.medium(fontSize: 11, color: colors.aiAccent),
          ),
          const SizedBox(height: 4),
          Text(
            q.topic.isEmpty ? 'Question' : q.topic,
            style: AppTypography.semiBold(fontSize: 15),
          ),
          if (made != null)
            Text(
              'Made ${DateFormatter.dateTime(made)}',
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.textMuted,
              ),
            ),
          const SizedBox(height: 8),
          Text(q.vignette, style: AppTypography.regular(height: 1.4)),
          const SizedBox(height: 6),
          Text(q.leadIn, style: AppTypography.semiBold(fontSize: 14)),
          const SizedBox(height: 6),
          for (int i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${String.fromCharCode(65 + i)}. ${q.options[i]}'
                '${q.correctIndex == i ? '  (keyed)' : ''}',
                style: AppTypography.regular(
                  fontSize: 13,
                  color: q.correctIndex == i
                      ? colors.success
                      : colors.textPrimary,
                ),
              ),
            ),
          if (q.explanation != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              q.explanation!,
              style: AppTypography.regular(
                fontSize: 12,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          busy
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : FilledButton.icon(
                  onPressed: locked ? null : () => cubit.markReviewed(draft),
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Mark reviewed'),
                ),
        ],
      ),
    );
  }
}
