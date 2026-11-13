import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/ai/widgets/summary_card.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/features/signout/bloc/signout_cubit.dart';
import 'package:round_ai/features/signout/models/contingency.dart';
import 'package:round_ai/features/signout/repository/signout_repository.dart';
import 'package:round_ai/shared/widgets/ai_error_box.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';
import 'package:round_ai/shared/widgets/app_input.dart';

const String signOutAiOffMessage =
    'AI is temporarily off. Manual entry still works.';
const String halfFilledContingencyMessage =
    'Fill in both the "if" and the "then", or remove the row.';

/// A sign-out draft on the real backend. The clinician types the
/// contingencies. The draft never writes them, and anything left out shows
/// as not entered.
class SignOutDraftScreen extends StatelessWidget {
  const SignOutDraftScreen({
    required this.patientId,
    this.signOutRepository,
    this.aiRepository,
    this.aiOff,
    super.key,
  });

  final String patientId;
  final SignOutRepository? signOutRepository;
  final AiRepository? aiRepository;

  /// Tests set this. The app reads the profile.
  final bool? aiOff;

  @override
  Widget build(BuildContext context) {
    final InjectionContainer di = InjectionContainer.instance;
    final AiRepository ai = aiRepository ?? di.aiRepository;
    return BlocProvider<SignOutCubit>(
      create: (_) => SignOutCubit(
        signOutRepository ?? di.signOutRepository,
        ai,
        patientId,
      ),
      child: _SignOutView(
        patientId: patientId,
        aiRepository: ai,
        aiOff: aiOff ?? di.profileRepository.aiOff,
      ),
    );
  }
}

class _Row {
  final TextEditingController condition = TextEditingController();
  final TextEditingController action = TextEditingController();

  bool get isEmpty =>
      condition.text.trim().isEmpty && action.text.trim().isEmpty;
  bool get isComplete =>
      condition.text.trim().isNotEmpty && action.text.trim().isNotEmpty;

  void dispose() {
    condition.dispose();
    action.dispose();
  }
}

class _SignOutView extends StatefulWidget {
  const _SignOutView({
    required this.patientId,
    required this.aiRepository,
    required this.aiOff,
  });

  final String patientId;
  final AiRepository aiRepository;
  final bool aiOff;

  @override
  State<_SignOutView> createState() => _SignOutViewState();
}

class _SignOutViewState extends State<_SignOutView> {
  final List<_Row> _rows = <_Row>[_Row()];
  bool _halfFilled = false;

  @override
  void dispose() {
    for (final _Row r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _remove(_Row row) {
    setState(() => _rows.remove(row));
    // The fields are still on screen for this frame. Dispose after it.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  void _generate() {
    final bool half = _rows.any((_Row r) => !r.isEmpty && !r.isComplete);
    setState(() => _halfFilled = half);
    if (half) return;
    context.read<SignOutCubit>().generate(<Contingency>[
      for (final _Row r in _rows)
        if (r.isComplete)
          Contingency(
            condition: r.condition.text.trim(),
            action: r.action.text.trim(),
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocBuilder<SignOutCubit, SignOutState>(
      builder: (BuildContext context, SignOutState state) {
        final SignOutCubit cubit = context.read<SignOutCubit>();
        final ApiError? error = state.error;
        return ChartEntryScaffold(
          title: 'Sign-out',
          bottom: state.generating
              ? AiProgressRow(
                  message: 'Writing the draft. This can take up to a minute.',
                  onCancel: cubit.cancel,
                )
              : SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.aiOff || state.reviewing
                        ? null
                        : _generate,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(
                      state.hasDraft ? 'Regenerate draft' : 'Generate draft',
                    ),
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  AiStateChip(state: state.aiState),
                  if (state.hasDraft && !state.isReviewed)
                    Text(
                      'AI draft · review required',
                      style: AppTypography.medium(
                        fontSize: 11,
                        color: colors.aiAccent,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Contingency instructions',
                style: AppTypography.semiBold(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'You write the if/then plans. None are invented. Without '
                'them the draft lists contingency instructions as not '
                'entered.',
                style: AppTypography.regular(
                  fontSize: 13,
                  height: 1.4,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < _rows.length; i++)
                _ContingencyRow(
                  row: _rows[i],
                  index: i,
                  enabled: !state.generating,
                  onRemove: _rows.length > 1 ? () => _remove(_rows[i]) : null,
                  onChanged: () => setState(() => _halfFilled = false),
                ),
              const FreeTextHint(),
              if (_halfFilled)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    halfFilledContingencyMessage,
                    style: AppTypography.regular(
                      fontSize: 12,
                      color: colors.critical,
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: state.generating
                    ? null
                    : () => setState(() => _rows.add(_Row())),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add contingency'),
              ),
              if (widget.aiOff) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  signOutAiOffMessage,
                  style: AppTypography.regular(
                    fontSize: 12,
                    color: colors.critical,
                  ),
                ),
              ],
              if (error != null) ...<Widget>[
                const SizedBox(height: 12),
                AiErrorBox(
                  error: error,
                  onRetry: error.isRetryable ? _generate : null,
                  onReviewFacts: error.kind == ApiErrorKind.noReviewedFacts
                      ? () => context.push<Object>(
                          AppRoutes.patientFactsPath(widget.patientId),
                        )
                      : null,
                ),
              ],
              if (state.hasDraft) ...<Widget>[
                const SizedBox(height: 18),
                SummaryBody(
                  envelope: state.envelope!,
                  content: state.content!,
                  marked: state.markedSections,
                  repository: widget.aiRepository,
                ),
                if (state.reviewError != null)
                  AiErrorBox(
                    error: state.reviewError!,
                    sections: state.flaggedSections.length,
                  ),
                if (!state.isReviewed)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: state.canMarkReviewed
                          ? cubit.markReviewed
                          : null,
                      icon: state.reviewing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_outlined, size: 18),
                      label: const Text('Mark reviewed'),
                    ),
                  ),
                if (state.reviewBlockedReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      state.reviewBlockedReason!,
                      style: AppTypography.regular(
                        fontSize: 12,
                        color: colors.warning,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ContingencyRow extends StatelessWidget {
  const _ContingencyRow({
    required this.row,
    required this.index,
    required this.enabled,
    required this.onChanged,
    this.onRemove,
  });

  final _Row row;
  final int index;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Contingency ${index + 1}',
                  style: AppTypography.medium(fontSize: 13),
                ),
              ),
              if (onRemove != null)
                TextButton(
                  onPressed: enabled ? onRemove : null,
                  child: const Text('Remove'),
                ),
            ],
          ),
          TextField(
            controller: row.condition,
            enabled: enabled,
            onChanged: (String _) => onChanged(),
            decoration: appInputDecoration(
              context,
              label: 'If',
              hint: 'For example: chest pain overnight',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.action,
            enabled: enabled,
            onChanged: (String _) => onChanged(),
            decoration: appInputDecoration(
              context,
              label: 'Then',
              hint: 'What the night team should do',
            ),
          ),
        ],
      ),
    );
  }
}
