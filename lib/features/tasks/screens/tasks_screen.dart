import 'package:flutter/material.dart';
import 'package:round_ai/shared/widgets/demo_content_banner.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/patient/data/patient_workspace.dart';
import 'package:round_ai/shared/widgets/workflow_page.dart';

/// Command center for the team. With a [patientId] it lists only that
/// patient's tasks inside the patient workflow.
class TasksScreen extends StatelessWidget {
  const TasksScreen({this.patientId, super.key});

  final String? patientId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: DemoTaskBoard.changes,
      builder: (BuildContext context, int _, Widget? child) {
        final AppColors colors = AppColors.of(context);
        final List<ChartTask> tasks = allDemoTasks
            .where(
              (ChartTask t) => patientId == null || t.patientId == patientId,
            )
            .toList();
        final List<ChartTask> open = tasks
            .where((ChartTask t) => !DemoTaskBoard.isDone(t.id))
            .toList();
        final List<ChartTask> done = tasks
            .where((ChartTask t) => DemoTaskBoard.isDone(t.id))
            .toList();
        final List<ChartTask> dueNow = open
            .where((ChartTask t) => t.dueNow)
            .toList();
        final List<ChartTask> later = open
            .where((ChartTask t) => !t.dueNow)
            .toList();

        final List<Widget> children = <Widget>[
          _StatsRow(
            open: open.length,
            dueNow: dueNow.length,
            done: done.length,
          ),
          const SizedBox(height: 20),
          if (tasks.isEmpty)
            _Empty(colors: colors)
          else ...<Widget>[
            if (dueNow.isNotEmpty) ...<Widget>[
              _SectionTitle('Priority'),
              ...dueNow.map((ChartTask t) => _TaskTile(task: t)),
              const SizedBox(height: 12),
            ],
            if (later.isNotEmpty) ...<Widget>[
              _SectionTitle('Later today'),
              ...later.map((ChartTask t) => _TaskTile(task: t)),
              const SizedBox(height: 12),
            ],
            if (done.isNotEmpty) ...<Widget>[
              _SectionTitle('Completed'),
              ...done.map((ChartTask t) => _TaskTile(task: t)),
            ],
          ],
        ];

        if (patientId != null) {
          return WorkflowPage(
            title: 'Tasks',
            status: '${open.length} open',
            children: children,
          );
        }

        return Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: <Widget>[
                const DemoContentBanner(forceShow: true),
                Text(
                  'COMMAND CENTER',
                  style: AppTypography.semiBold(
                    fontSize: 11,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tasks',
                  style: AppTypography.bold(
                    fontSize: 28,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.open,
    required this.dueNow,
    required this.done,
  });

  final int open;
  final int dueNow;
  final int done;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: _Stat(value: '$open', label: 'Open', color: colors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            value: '$dueNow',
            label: 'Due now',
            color: dueNow > 0 ? colors.critical : colors.textMuted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            value: '$done',
            label: 'Completed',
            color: colors.success,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: AppTypography.bold(fontSize: 26, color: color)),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.regular(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: AppTypography.semiBold(fontSize: 16, color: colors.textPrimary),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final ChartTask task;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool done = DemoTaskBoard.isDone(task.id);
    final Color dueColor = task.dueNow && !done
        ? colors.critical
        : colors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => DemoTaskBoard.toggle(task.id),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: done ? colors.success : colors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        task.patientName,
                        style: AppTypography.regular(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.title,
                        style:
                            AppTypography.semiBold(
                              fontSize: 15,
                              color: done
                                  ? colors.textMuted
                                  : colors.textPrimary,
                            ).copyWith(
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  done ? 'Done' : task.due,
                  style: AppTypography.semiBold(fontSize: 12, color: dueColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Text(
        'No tasks yet. Add one from Rounds.',
        textAlign: TextAlign.center,
        style: AppTypography.regular(color: colors.textSecondary),
      ),
    );
  }
}
