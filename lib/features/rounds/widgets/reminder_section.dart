import 'package:flutter/material.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/ai/widgets/source_drawer.dart';
import 'package:round_ai/features/rounds/models/round_reminder.dart';
import 'package:round_ai/features/rounds/repository/round_repository.dart';

/// Approved checklist reminders ("Prompt for your consideration").
class ReminderSection extends StatefulWidget {
  const ReminderSection({
    required this.patientId,
    required this.reminders,
    this.comparisons = const <YesterdayComparison>[],
    this.repository,
    this.aiRepository,
    this.onChanged,
    super.key,
  });

  final String patientId;
  final List<RoundReminder> reminders;
  final List<YesterdayComparison> comparisons;
  final RoundRepository? repository;
  final AiRepository? aiRepository;
  final VoidCallback? onChanged;

  @override
  State<ReminderSection> createState() => _ReminderSectionState();
}

class _ReminderSectionState extends State<ReminderSection> {
  late List<RoundReminder> _reminders = List<RoundReminder>.of(widget.reminders);
  String? _busyRuleId;

  RoundRepository get _repo =>
      widget.repository ?? InjectionContainer.instance.roundRepository;

  AiRepository get _ai =>
      widget.aiRepository ?? InjectionContainer.instance.aiRepository;

  @override
  void didUpdateWidget(covariant ReminderSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reminders != widget.reminders) {
      _reminders = List<RoundReminder>.of(widget.reminders);
    }
  }

  Future<void> _ack(RoundReminder reminder, ReminderAckState state) async {
    String? note;
    if (state == ReminderAckState.snoozed) {
      note = await showDialog<String>(
        context: context,
        builder: (BuildContext ctx) => const _SnoozeNoteDialog(),
      );
      if (note == null) return;
      if (note.isEmpty) note = null;
    }
    setState(() => _busyRuleId = reminder.ruleId);
    final Result<ReminderAck> result = await _repo.ackReminder(
      widget.patientId,
      reminder.ruleId,
      state: state,
      note: note,
    );
    if (!mounted) return;
    setState(() => _busyRuleId = null);
    switch (result) {
      case Ok<ReminderAck>(:final ReminderAck value):
        setState(() {
          _reminders = _reminders
              .map(
                (RoundReminder r) =>
                    r.ruleId == reminder.ruleId ? r.copyWith(ack: value) : r,
              )
              .toList();
        });
        widget.onChanged?.call();
      case Err<ReminderAck>(:final Failure failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  void _openFact(CompareFact fact) {
    showSourceDrawer(
      context,
      claim: Claim(
        text: fact.display,
        label: ClaimLabel.fromChart,
        factIds: <String>[fact.factId],
      ),
      repository: _ai,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          reminderFrame.toUpperCase(),
          style: AppTypography.semiBold(fontSize: 11, color: colors.textMuted),
        ),
        const SizedBox(height: 8),
        if (_reminders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.warningSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Reminders need admin approval',
                  style: AppTypography.semiBold(
                    fontSize: 13,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  remindersEmptyMessage,
                  style: AppTypography.regular(
                    fontSize: 12,
                    height: 1.4,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ..._reminders.map((RoundReminder r) => _ReminderCard(
                reminder: r,
                busy: _busyRuleId == r.ruleId,
                onAck: _ack,
              )),
        if (widget.comparisons.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            'Yesterday comparison',
            style: AppTypography.semiBold(
              fontSize: 15,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.comparisons.map(
            (YesterdayComparison c) => _CompareBlock(
              comparison: c,
              onFactTap: _openFact,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.busy,
    required this.onAck,
  });

  final RoundReminder reminder;
  final bool busy;
  final Future<void> Function(RoundReminder, ReminderAckState) onAck;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            reminder.name,
            style: AppTypography.semiBold(
              fontSize: 14,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reminder.frame,
            style: AppTypography.regular(fontSize: 11, color: colors.textMuted),
          ),
          if (reminder.prompts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ...reminder.prompts.map(
              (ReminderPrompt p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${p.text}',
                  style: AppTypography.regular(
                    fontSize: 13,
                    height: 1.4,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
          if (reminder.ack != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Recorded · ${reminder.ack!.state.label}',
              style: AppTypography.semiBold(
                fontSize: 12,
                color: colors.success,
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final ReminderAckState s in ReminderAckState.values)
                  TextButton(
                    onPressed: busy ? null : () => onAck(reminder, s),
                    child: Text(s.label),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CompareBlock extends StatelessWidget {
  const _CompareBlock({required this.comparison, required this.onFactTap});

  final YesterdayComparison comparison;
  final void Function(CompareFact) onFactTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final YesterdayCompareBlock? block = comparison.compare;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            comparison.ruleName,
            style: AppTypography.semiBold(
              fontSize: 13,
              color: colors.textPrimary,
            ),
          ),
          if (block?.message.isNotEmpty ?? false) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              block!.message,
              style: AppTypography.regular(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ],
          if (block != null)
            ...block.facts.map(
              (CompareFact f) => TextButton(
                onPressed: () => onFactTap(f),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  f.display,
                  style: AppTypography.regular(
                    fontSize: 13,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SnoozeNoteDialog extends StatefulWidget {
  const _SnoozeNoteDialog();

  @override
  State<_SnoozeNoteDialog> createState() => _SnoozeNoteDialogState();
}

class _SnoozeNoteDialogState extends State<_SnoozeNoteDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Snooze'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Optional note',
        ),
        maxLength: 500,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Snooze'),
        ),
      ],
    );
  }
}
