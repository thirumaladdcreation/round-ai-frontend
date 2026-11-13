import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/date_format.dart';
import 'package:round_ai/features/tasks/models/patient_task.dart';

/// One task. Missing owner or due time reads "Unassigned" or "No due time".
/// Nothing is guessed.
class TaskTile extends StatelessWidget {
  const TaskTile({
    required this.task,
    required this.now,
    this.busy = false,
    this.onComplete,
    this.actions = const <Widget>[],
    this.badge,
    super.key,
  });

  final PatientTask task;
  final DateTime now;
  final bool busy;

  /// Shown as a Complete button for an open task.
  final VoidCallback? onComplete;

  /// Extra buttons under the text, such as Accept and Dismiss.
  final List<Widget> actions;

  /// A small label above the title, such as the AI draft label.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool done = task.status == TaskStatus.completed;
    final bool overdue = task.isOverdue(now);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (badge != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                badge!,
                style: AppTypography.medium(
                  fontSize: 11,
                  color: colors.aiAccent,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  task.title,
                  style:
                      AppTypography.semiBold(
                        fontSize: 15,
                        color: done ? colors.textMuted : colors.textPrimary,
                      ).copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (onComplete != null)
                IconButton(
                  tooltip: 'Complete',
                  onPressed: onComplete,
                  icon: Icon(
                    Icons.radio_button_unchecked_rounded,
                    color: colors.textMuted,
                  ),
                ),
              if (done) Icon(Icons.check_circle_rounded, color: colors.success),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            <String>[
              task.owner ?? 'Unassigned',
              task.dueAt == null
                  ? 'No due time'
                  : 'Due ${DateFormatter.dateTime(task.dueAt!)}',
            ].join(' · '),
            style: AppTypography.regular(
              fontSize: 12,
              color: overdue ? colors.critical : colors.textSecondary,
            ),
          ),
          if (overdue)
            Text(
              'Overdue',
              style: AppTypography.semiBold(
                fontSize: 11,
                color: colors.critical,
              ),
            ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 8, children: actions),
            ),
        ],
      ),
    );
  }
}
