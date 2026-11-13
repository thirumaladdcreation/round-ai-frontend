import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/patient/models/chart_source.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository.dart';

enum SourcePhase { idle, saving, extracting }

class AddSourceState extends Equatable {
  const AddSourceState({
    this.phase = SourcePhase.idle,
    this.error,
    this.sourceId,
    this.done = false,
  });

  final SourcePhase phase;
  final String? error;

  /// Set once the text is saved. If extraction fails, Retry reuses it, so the
  /// text is not saved twice.
  final String? sourceId;

  /// Saved and, if asked, extracted. The screen moves on.
  final bool done;

  bool get busy => phase != SourcePhase.idle;

  @override
  List<Object?> get props => <Object?>[phase, error, sourceId, done];
}

/// Add source text, then read facts from it. The facts stay pending until a
/// clinician confirms them on the review screen.
class AddSourceCubit extends Cubit<AddSourceState> {
  AddSourceCubit(this._repository, this.patientId)
    : super(const AddSourceState());

  final ChartDataRepository _repository;
  final String patientId;

  Future<void> submit({
    required ChartSourceKind kind,
    required DateTime time,
    required String text,
    required bool extract,
  }) async {
    if (state.busy) return;
    String? sourceId = state.sourceId;
    if (sourceId == null) {
      emit(const AddSourceState(phase: SourcePhase.saving));
      final Result<ChartSource> saved = await _repository.addSource(
        patientId,
        kind: kind,
        time: time,
        text: text,
      );
      switch (saved) {
        case Err<ChartSource>(:final failure):
          emit(AddSourceState(error: failure.message));
          return;
        case Ok<ChartSource>(:final value):
          sourceId = value.id;
      }
    }
    if (!extract) {
      emit(AddSourceState(sourceId: sourceId, done: true));
      return;
    }
    emit(AddSourceState(phase: SourcePhase.extracting, sourceId: sourceId));
    final Result<void> extracted = await _repository.extract(
      patientId,
      sourceId,
    );
    switch (extracted) {
      case Err<void>(:final failure):
        emit(AddSourceState(sourceId: sourceId, error: failure.message));
      case Ok<void>():
        emit(AddSourceState(sourceId: sourceId, done: true));
    }
  }
}
