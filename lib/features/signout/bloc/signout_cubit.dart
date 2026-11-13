import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/features/ai/bloc/summary_cubit.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/models/summary_content.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/signout/models/contingency.dart';
import 'package:round_ai/features/signout/repository/signout_repository.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';

class SignOutState extends Equatable {
  const SignOutState({
    this.generating = false,
    this.envelope,
    this.content,
    this.error,
    this.reviewing = false,
    this.reviewError,
    this.flaggedSections = const <String>[],
  });

  final bool generating;
  final AiEnvelope? envelope;
  final SummaryContent? content;
  final ApiError? error;
  final bool reviewing;
  final ApiError? reviewError;
  final List<String> flaggedSections;

  bool get hasDraft => envelope != null;
  bool get isReviewed => envelope?.isReviewed ?? false;

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
      hasDraft &&
      !isReviewed &&
      reviewBlockedReason == null &&
      !generating &&
      !reviewing;

  Set<String> get markedSections => <String>{
    ...?content?.placeholderSections,
    ...flaggedSections,
  };

  SignOutState copyWith({
    bool? generating,
    AiEnvelope? envelope,
    SummaryContent? content,
    ApiError? error,
    bool clearError = false,
    bool? reviewing,
    ApiError? reviewError,
    bool clearReviewError = false,
    List<String>? flaggedSections,
  }) {
    return SignOutState(
      generating: generating ?? this.generating,
      envelope: envelope ?? this.envelope,
      content: content ?? this.content,
      error: clearError ? null : error ?? this.error,
      reviewing: reviewing ?? this.reviewing,
      reviewError: clearReviewError ? null : reviewError ?? this.reviewError,
      flaggedSections: flaggedSections ?? this.flaggedSections,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    generating,
    envelope,
    content,
    error?.code,
    reviewing,
    reviewError?.code,
    flaggedSections,
  ];
}

/// A sign-out draft. The clinician types the contingencies. The draft never
/// writes its own, and what is missing is listed as not entered.
class SignOutCubit extends Cubit<SignOutState> {
  SignOutCubit(this._signOut, this._ai, this.patientId)
    : super(const SignOutState());

  final SignOutRepository _signOut;
  final AiRepository _ai;
  final String patientId;

  String? _key;
  List<Contingency>? _lastInputs;
  CancelToken? _cancel;

  SignOutState _withDraft(AiEnvelope envelope) => SignOutState(
    envelope: envelope,
    content: SummaryContent.fromEnvelope(envelope),
  );

  /// Makes the draft. A retry with the same contingencies keeps the key.
  Future<void> generate(List<Contingency> contingencies) async {
    if (state.generating) return;
    // Different contingencies are a different action, so a new key.
    if (!listEquals(_lastInputs, contingencies)) _key = null;
    _lastInputs = List<Contingency>.of(contingencies);
    _key ??= IdempotencyKey.create();
    final CancelToken token = _cancel = CancelToken();
    emit(
      state.copyWith(
        generating: true,
        clearError: true,
        clearReviewError: true,
        flaggedSections: const <String>[],
      ),
    );
    final Result<AiEnvelope> result = await _signOut.generate(
      patientId,
      contingencies: contingencies,
      idempotencyKey: _key!,
      cancelToken: token,
    );
    if (isClosed) return;
    switch (result) {
      case Err<AiEnvelope>(:final failure):
        final ApiError error = failure.apiError;
        if (error.kind == ApiErrorKind.cancelled) {
          _key = null;
          emit(state.copyWith(generating: false));
          return;
        }
        if (!error.isRetryable) _key = null;
        emit(state.copyWith(generating: false, error: error));
      case Ok<AiEnvelope>(:final value):
        _key = null;
        emit(_withDraft(value));
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
    final Result<AiEnvelope> result = await _ai.markReviewed(
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
      case Ok<AiEnvelope>(:final value):
        emit(_withDraft(value));
    }
  }

  @override
  Future<void> close() {
    _cancel?.cancel();
    return super.close();
  }
}
