import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/core/utils/date_format.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/features/tasks/bloc/patient_tasks_cubit.dart';
import 'package:round_ai/features/tasks/models/patient_task.dart';
import 'package:round_ai/features/tasks/repository/tasks_repository.dart';
import 'package:round_ai/features/tasks/widgets/task_tile.dart';
import 'package:round_ai/shared/widgets/ai_error_box.dart';
import 'package:round_ai/shared/widgets/app_input.dart';
import 'package:round_ai/shared/widgets/retry_view.dart';
import 'package:round_ai/shared/widgets/skeleton.dart';

const String tasksAiOffMessage =
    'AI is temporarily off. Manual entry still works.';
const String noPlanMessage =
    'Tasks are proposed from your saved plan. Add a plan first.';

/// One patient's tasks on the real backend. Proposed tasks are listed apart
/// from open ones and become tasks only when the clinician accepts them.
class PatientTasksScreen extends StatelessWidget {
  const PatientTasksScreen({
    required this.patientId,
    this.tasksRepository,
    this.patientRepository,
    this.aiOff,
    super.key,
  });

  final String patientId;
  final TasksRepository? tasksRepository;
  final PatientRepository? patientRepository;

  /// Tests set this. The app reads the profile.
  final bool? aiOff;

  @override
  Widget build(BuildContext context) {
    final InjectionContainer di = InjectionContainer.instance;
    return BlocProvider<PatientTasksCubit>(
      create: (_) => PatientTasksCubit(
        tasksRepository ?? di.tasksRepository,
        patientRepository ?? di.patientRepository,
        patientId,
      )..load(),
      child: _TasksView(
        patientId: patientId,
        aiOff: aiOff ?? di.profileRepository.aiOff,
      ),
    );
  }
}

class _TasksView extends StatelessWidget {
  const _TasksView({required this.patientId, required this.aiOff});

  final String patientId;
  final bool aiOff;

  Future<void> _add(BuildContext context) async {
    final PatientTasksCubit cubit = context.read<PatientTasksCubit>();
    final TaskInput? input = await showDialog<TaskInput>(
      context: context,
      builder: (BuildContext dialog) =>
          const TaskDetailsDialog(heading: 'Add a task', askTitle: true),
    );
    if (input != null) {
      await cubit.add(
        title: input.title,
        owner: input.owner,
        dueAt: input.dueAt,
      );
    }
  }

  Future<void> _accept(BuildContext context, PatientTask task) async {
    final PatientTasksCubit cubit = context.read<PatientTasksCubit>();
    final TaskInput? input = await showDialog<TaskInput>(
      context: context,
      builder: (BuildContext dialog) => TaskDetailsDialog(
        heading: 'Accept this task',
        askTitle: false,
        initialTitle: task.title,
      ),
    );
    if (input != null) {
      await cubit.accept(task, owner: input.owner, dueAt: input.dueAt);
    }
  }

  Future<void> _addPlan(BuildContext context) async {
    final PatientTasksCubit cubit = context.read<PatientTasksCubit>();
    await context.push<Object>(AppRoutes.patientPlanPath(patientId));
    await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocBuilder<PatientTasksCubit, PatientTasksState>(
      builder: (BuildContext context, PatientTasksState state) {
        final PatientTasksCubit cubit = context.read<PatientTasksCubit>();
        final DateTime now = DateTime.now();
        return ChartEntryScaffold(
          title: 'Tasks',
          onRefresh: cubit.load,
          child: state.loading && state.tasks.isEmpty
              ? const SkeletonColumn(count: 3)
              : state.loadError != null
              ? SizedBox(
                  height: 280,
                  child: RetryView(
                    title: 'Tasks could not be loaded.',
                    message: state.loadError!.userMessage,
                    onRetry: cubit.load,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _ProposeBar(
                      state: state,
                      aiOff: aiOff,
                      onAddPlan: () => _addPlan(context),
                    ),
                    if (state.actionError != null)
                      AiErrorBox(error: state.actionError!),
                    if (state.proposed.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      _Heading('Proposed', 'Not tasks until you accept them.'),
                      for (final PatientTask t in state.proposed)
                        TaskTile(
                          task: t,
                          now: now,
                          busy: state.busyId == t.id,
                          badge: 'AI draft · review required',
                          actions: <Widget>[
                            FilledButton.tonal(
                              onPressed: state.busyId != null
                                  ? null
                                  : () => _accept(context, t),
                              child: const Text('Accept'),
                            ),
                            OutlinedButton(
                              onPressed: state.busyId != null
                                  ? null
                                  : () => cubit.dismiss(t),
                              child: const Text('Dismiss'),
                            ),
                          ],
                        ),
                    ],
                    const SizedBox(height: 14),
                    _Heading('Open', '${state.open.length} open'),
                    if (state.open.isEmpty)
                      Text(
                        'No open tasks.',
                        style: AppTypography.regular(
                          color: colors.textSecondary,
                        ),
                      ),
                    for (final PatientTask t in state.open)
                      TaskTile(
                        task: t,
                        now: now,
                        busy: state.busyId == t.id,
                        onComplete: state.busyId != null
                            ? null
                            : () => cubit.complete(t),
                      ),
                    if (state.completed.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      _Heading('Completed', '${state.completed.length} done'),
                      for (final PatientTask t in state.completed)
                        TaskTile(task: t, now: now),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: state.adding ? null : () => _add(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add task'),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.caption);

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text(title, style: AppTypography.semiBold(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              caption,
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposeBar extends StatelessWidget {
  const _ProposeBar({
    required this.state,
    required this.aiOff,
    required this.onAddPlan,
  });

  final PatientTasksState state;
  final bool aiOff;
  final VoidCallback onAddPlan;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final PatientTasksCubit cubit = context.read<PatientTasksCubit>();
    if (state.proposing) {
      return AiProgressRow(
        message: 'Proposing tasks. This can take up to a minute.',
        onCancel: cubit.cancelPropose,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: aiOff || !state.canPropose ? null : cubit.propose,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Propose tasks from plan'),
          ),
        ),
        if (state.hasPlan == false) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            noPlanMessage,
            style: AppTypography.regular(fontSize: 12, color: colors.warning),
          ),
          TextButton(onPressed: onAddPlan, child: const Text('Add plan')),
        ],
        if (aiOff)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              tasksAiOffMessage,
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.critical,
              ),
            ),
          ),
        if (state.proposedCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'No tasks were proposed from the plan.',
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ),
        if (state.proposeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AiErrorBox(
              error: state.proposeError!,
              onRetry: state.proposeError!.isRetryable ? cubit.propose : null,
            ),
          ),
      ],
    );
  }
}

/// What the task dialog collects.
class TaskInput {
  const TaskInput({required this.title, this.owner, this.dueAt});

  final String title;
  final String? owner;
  final DateTime? dueAt;
}

/// Collects a title (when asked), an optional owner and an optional due
/// time. It owns its controllers, so they are disposed after it has gone.
class TaskDetailsDialog extends StatefulWidget {
  const TaskDetailsDialog({
    required this.heading,
    required this.askTitle,
    this.initialTitle = '',
    super.key,
  });

  final String heading;
  final bool askTitle;
  final String initialTitle;

  @override
  State<TaskDetailsDialog> createState() => _TaskDetailsDialogState();
}

class _TaskDetailsDialogState extends State<TaskDetailsDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initialTitle,
  );
  final TextEditingController _owner = TextEditingController();
  DateTime? _due;

  @override
  void dispose() {
    _title.dispose();
    _owner.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due ?? now),
    );
    if (time == null) return;
    setState(() {
      _due = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canSave = !widget.askTitle || _title.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.heading),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.askTitle) ...<Widget>[
              TextField(
                controller: _title,
                onChanged: (String _) => setState(() {}),
                decoration: appInputDecoration(context, label: 'Task'),
              ),
              const FreeTextHint(),
              const SizedBox(height: 12),
            ] else ...<Widget>[
              Text(widget.initialTitle),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _owner,
              decoration: appInputDecoration(
                context,
                label: 'Owner (optional)',
                helper: 'Left blank, the task stays unassigned.',
              ),
            ),
            const FreeTextHint(),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickDue,
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(
                _due == null
                    ? 'Due time (optional)'
                    : 'Due ${DateFormatter.dateTime(_due!)}',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: canSave
              ? () => Navigator.pop(
                  context,
                  TaskInput(
                    title: _title.text.trim(),
                    owner: _owner.text.trim().isEmpty
                        ? null
                        : _owner.text.trim(),
                    dueAt: _due,
                  ),
                )
              : null,
          child: Text(widget.askTitle ? 'Add' : 'Accept'),
        ),
      ],
    );
  }
}
