import 'package:flutter/material.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';

/// States every AI component must be able to show.
enum AiState {
  notGenerated('Not generated', Icons.hourglass_empty_rounded),
  queued('Queued', Icons.schedule_rounded),
  loading('Loading', Icons.autorenew_rounded),
  draftReady('Draft ready', Icons.edit_note_rounded),
  reviewed('Reviewed', Icons.verified_rounded),
  outdated('Outdated', Icons.update_disabled_rounded),
  partial('Partial result', Icons.pie_chart_outline_rounded),
  noEvidence('No relevant evidence', Icons.search_off_rounded),
  failed('Failed', Icons.error_outline_rounded),
  refused('Refused', Icons.block_rounded),
  accessDenied('Access denied', Icons.lock_outline_rounded),
  unavailable('Unavailable', Icons.cloud_off_rounded);

  const AiState(this.label, this.icon);

  final String label;
  final IconData icon;

  /// State of a saved artifact. `null` means nothing was generated yet.
  /// Loading, Failed, and Unavailable describe a request, not an artifact,
  /// so the screen sets those itself. Queued is not used until the backend
  /// becomes asynchronous.
  static AiState fromEnvelope(AiEnvelope? envelope) {
    if (envelope == null) return AiState.notGenerated;
    if (envelope.outdated) return AiState.outdated;
    if (envelope.isReviewed) return AiState.reviewed;
    if (envelope.isPartial) return AiState.partial;
    return AiState.draftReady;
  }

  /// State from the census pill, before the artifact itself is loaded.
  static AiState fromSummary(SummaryState state) {
    return switch (state) {
      SummaryState.notGenerated => AiState.notGenerated,
      SummaryState.draftReady => AiState.draftReady,
      SummaryState.reviewed => AiState.reviewed,
      SummaryState.outdated => AiState.outdated,
    };
  }

  /// State to show when a request fails.
  static AiState fromError(ApiError error) {
    return switch (error.kind) {
      ApiErrorKind.aiDisabled => AiState.unavailable,
      ApiErrorKind.accessDenied => AiState.accessDenied,
      _ => AiState.failed,
    };
  }

  /// A finished draft can be copied or reviewed. Anything else cannot.
  bool get canReview => this == AiState.draftReady;
}

class AiStateChip extends StatelessWidget {
  const AiStateChip({required this.state, super.key});

  final AiState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final (Color bg, Color fg) = switch (state) {
      AiState.reviewed => (colors.successSoft, colors.success),
      AiState.draftReady => (colors.primarySoft, colors.primary),
      AiState.outdated ||
      AiState.partial => (colors.warningSoft, colors.warning),
      AiState.failed ||
      AiState.refused ||
      AiState.accessDenied ||
      AiState.unavailable => (colors.criticalBg, colors.critical),
      _ => (colors.chipIdle, colors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(state.icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            state.label,
            style: AppTypography.semiBold(fontSize: 11, color: fg),
          ),
        ],
      ),
    );
  }
}
