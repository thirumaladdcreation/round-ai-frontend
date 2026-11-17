import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/sync/census_sync_mark.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/models/summary_content.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';

enum SummaryPhase { loading, idle, generating }

const String outdatedReviewMessage =
    'Chart changed. Regenerate before marking reviewed.';
const String placeholderReviewMessage =
    'Some sections still have information that is not entered. '
    'Add it to the chart and regenerate before marking reviewed.';

class SummaryCardState extends Equatable {
  const SummaryCardState({
    this.phase = SummaryPhase.loading,
    this.envelope,
    this.content,
    this.error,
    this.errorFromLoad = false,
    this.reviewing = false,
    this.reviewError,
    this.flaggedSections = const <String>[],
    this.changes = 0,
  });

  final SummaryPhase phase;

  /// The version on screen. `null` means nothing was generated yet.
  final AiEnvelope? envelope;
  final SummaryContent? content;

  /// The last load or generate that failed. The old version stays visible.
  final ApiError? error;

  /// Whether [error] came from reading the saved summary, so Retry reads it
  /// again instead of generating.
  final bool errorFromLoad;
  final bool reviewing;
  final ApiError? reviewError;

  /// Section keys the backend named when it refused to mark reviewed.
  final List<String> flaggedSections;

  /// Goes up when a summary is generated or reviewed, so the screen around
  /// it can reload.
  final int changes;

  bool get generating => phase == SummaryPhase.generating;
  bool get hasSummary => envelope != null;
  bool get outdated => envelope?.outdated ?? false;

  AiState get aiState {
    if (generating) return AiState.loading;
    final AiEnvelope? e = envelope;
    if (e == null) {
      final ApiError? err = error;
      return err == null ? AiState.notGenerated : AiState.fromError(err);
    }
    return AiState.fromEnvelope(e);
  }

  /// Why "Mark reviewed" is off, or `null` when it can be used.
  String? get reviewBlockedReason {
    final AiEnvelope? e = envelope;
    if (e == null || e.isReviewed) return null;
    if (e.outdated) return outdatedReviewMessage;
    if (content?.hasPlaceholders ?? false) return placeholderReviewMessage;
    return null;
  }

  bool get canMarkReviewed =>
      envelope != null &&
      !envelope!.isReviewed &&
      reviewBlockedReason == null &&
      !generating &&
      !reviewing;

  /// Sections to mark: the ones with "not entered" text plus any the backend
  /// named.
  Set<String> get markedSections => <String>{
    ...?content?.placeholderSections,
    ...flaggedSections,
  };

  SummaryCardState copyWith({
    SummaryPhase? phase,
    AiEnvelope? envelope,
    SummaryContent? content,
    ApiError? error,
    bool errorFromLoad = false,
    bool clearError = false,
    bool? reviewing,
    ApiError? reviewError,
    bool clearReviewError = false,
    List<String>? flaggedSections,
    int? changes,
  }) {
    return SummaryCardState(
      phase: phase ?? this.phase,
      envelope: envelope ?? this.envelope,
      content: content ?? this.content,
      error: clearError ? null : error ?? this.error,
      errorFromLoad: clearError
          ? false
          : (error != null ? errorFromLoad : this.errorFromLoad),
      reviewing: reviewing ?? this.reviewing,
      reviewError: clearReviewError ? null : reviewError ?? this.reviewError,
      flaggedSections: flaggedSections ?? this.flaggedSections,
      changes: changes ?? this.changes,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    phase,
    envelope,
    content,
    error?.code,
    errorFromLoad,
    reviewing,
    reviewError?.code,
    flaggedSections,
    changes,
  ];
}

/// The patient summary: load the newest one, generate, mark reviewed.
class SummaryCubit extends Cubit<SummaryCardState> {
  SummaryCubit(this._repository, this.patientId)
    : super(const SummaryCardState());

  final AiRepository _repository;
  final String patientId;

  String? _key;
  CancelToken? _cancel;

  SummaryCardState _withEnvelope(
    SummaryCardState from,
    AiEnvelope envelope, {
    SummaryPhase phase = SummaryPhase.idle,
    int? changes,
  }) {
    return SummaryCardState(
      phase: phase,
      envelope: envelope,
      content: SummaryContent.fromEnvelope(envelope),
      changes: changes ?? from.changes,
    );
  }

  Future<void> load() async {
    if (state.generating) return;
    final bool first = state.envelope == null;
    if (first) emit(state.copyWith(phase: SummaryPhase.loading));
    final Result<AiEnvelope?> result = await _repository.latestSummary(
      patientId,
    );
    if (isClosed) return;
    switch (result) {
      case Err<AiEnvelope?>(:final failure):
        emit(
          state.copyWith(
            phase: SummaryPhase.idle,
            error: failure.apiError,
            errorFromLoad: true,
          ),
        );
      case Ok<AiEnvelope?>(:final value):
        if (value == null) {
          emit(
            SummaryCardState(phase: SummaryPhase.idle, changes: state.changes),
          );
        } else {
          emit(_withEnvelope(state, value));
        }
    }
  }

  /// Makes a summary. The Idempotency-Key is made once per tap and kept
  /// while a retry is possible, so a retry never makes a second summary.
  Future<void> generate() async {
    if (state.generating) return;
    _key ??= IdempotencyKey.create();
    final CancelToken token = _cancel = CancelToken();
    emit(
      state.copyWith(
        phase: SummaryPhase.generating,
        clearError: true,
        clearReviewError: true,
        flaggedSections: const <String>[],
      ),
    );
    final Result<AiEnvelope> result = await _repository.generateSummary(
      patientId,
      idempotencyKey: _key!,
      cancelToken: token,
    );
    if (isClosed) return;
    switch (result) {
      case Err<AiEnvelope>(:final failure):
        final ApiError error = failure.apiError;
        if (error.kind == ApiErrorKind.cancelled) {
          // The user stopped it. The next tap is a new action.
          _key = null;
          emit(state.copyWith(phase: SummaryPhase.idle));
          return;
        }
        // Only a failure Retry can fix keeps the key.
        if (!error.isRetryable) _key = null;
        emit(state.copyWith(phase: SummaryPhase.idle, error: error));
      case Ok<AiEnvelope>(:final value):
        _key = null;
        markCensusDirty();
        emit(_withEnvelope(state, value, changes: state.changes + 1));
    }
  }

  void cancel() => _cancel?.cancel();

  Future<void> markReviewed() async {
    final AiEnvelope? envelope = state.envelope;
    if (envelope == null || !state.canMarkReviewed) return;
    emit(
      state.copyWith(
        reviewing: true,
        clearReviewError: true,
        flaggedSections: const <String>[],
      ),
    );
    final Result<AiEnvelope> result = await _repository.markReviewed(
      envelope.artifactId,
    );
    if (isClosed) return;
    switch (result) {
      case Err<AiEnvelope>(:final failure):
        final ApiError error = failure.apiError;
        emit(
          state.copyWith(
            reviewing: false,
            reviewError: error,
            flaggedSections: error.sections,
          ),
        );
        // The chart moved on. Read the current version so Outdated shows.
        if (error.kind == ApiErrorKind.outdated) {
          await load();
          if (!isClosed) emit(state.copyWith(reviewError: error));
        }
      case Ok<AiEnvelope>(:final value):
        markCensusDirty();
        emit(_withEnvelope(state, value, changes: state.changes + 1));
    }
  }

  @override
  Future<void> close() {
    _cancel?.cancel();
    return super.close();
  }
}
