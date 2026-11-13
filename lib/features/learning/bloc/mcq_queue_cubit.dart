import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/learning/models/mcq_draft.dart';
import 'package:round_ai/features/learning/repository/teach_repository.dart';

class McqQueueState extends Equatable {
  const McqQueueState({
    this.loading = true,
    this.items = const <McqDraft>[],
    this.error,
    this.reviewingId,
    this.reviewError,
  });

  final bool loading;

  /// Questions that still need a reviewer.
  final List<McqDraft> items;
  final ApiError? error;
  final String? reviewingId;
  final ApiError? reviewError;

  McqQueueState copyWith({
    bool? loading,
    List<McqDraft>? items,
    ApiError? error,
    bool clearError = false,
    String? reviewingId,
    bool clearReviewing = false,
    ApiError? reviewError,
    bool clearReviewError = false,
  }) {
    return McqQueueState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      error: clearError ? null : error ?? this.error,
      reviewingId: clearReviewing ? null : reviewingId ?? this.reviewingId,
      reviewError: clearReviewError ? null : reviewError ?? this.reviewError,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    loading,
    items,
    error?.code,
    reviewingId,
    reviewError?.code,
  ];
}

/// Generated questions waiting for review. Reviewing one is an explicit tap.
class McqQueueCubit extends Cubit<McqQueueState> {
  McqQueueCubit(this._teach, this._ai, this.patientId)
    : super(const McqQueueState());

  final TeachRepository _teach;
  final AiRepository _ai;
  final String patientId;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    final Result<List<McqDraft>> result = await _teach.questions(patientId);
    if (isClosed) return;
    switch (result) {
      case Err<List<McqDraft>>(:final failure):
        emit(state.copyWith(loading: false, error: failure.apiError));
      case Ok<List<McqDraft>>(:final value):
        emit(
          state.copyWith(
            loading: false,
            items: <McqDraft>[
              for (final McqDraft d in value)
                if (!d.isReviewed) d,
            ],
          ),
        );
    }
  }

  /// Marks one question reviewed, then it leaves the queue.
  Future<void> markReviewed(McqDraft draft) async {
    if (state.reviewingId != null) return;
    emit(
      state.copyWith(
        reviewingId: draft.envelope.artifactId,
        clearReviewError: true,
      ),
    );
    final Result<AiEnvelope> result = await _ai.markReviewed(
      draft.envelope.artifactId,
    );
    if (isClosed) return;
    switch (result) {
      case Err<AiEnvelope>(:final failure):
        emit(
          state.copyWith(clearReviewing: true, reviewError: failure.apiError),
        );
      case Ok<AiEnvelope>():
        emit(
          state.copyWith(
            clearReviewing: true,
            items: <McqDraft>[
              for (final McqDraft d in state.items)
                if (d.envelope.artifactId != draft.envelope.artifactId) d,
            ],
          ),
        );
    }
  }
}
