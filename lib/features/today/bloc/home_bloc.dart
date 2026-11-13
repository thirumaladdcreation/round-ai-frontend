import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/today/bloc/home_event.dart';
import 'package:round_ai/features/today/bloc/home_state.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/repository/home_repository.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc(this._repository) : super(const HomeLoading()) {
    on<HomeRequested>(_onRequested);
    on<HomeRefreshed>(_onRefreshed);
  }

  final HomeRepository _repository;

  Future<void> _onRequested(
    HomeRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeLoading());
    final Result<HomeSnapshot> result = await _repository.load();
    result.when(
      ok: (HomeSnapshot snapshot) => emit(HomeReady(snapshot)),
      err: (failure) => emit(HomeFailure(failure.message)),
    );
  }

  Future<void> _onRefreshed(
    HomeRefreshed event,
    Emitter<HomeState> emit,
  ) async {
    final Result<HomeSnapshot> result = await _repository.load();
    if (event.done?.isCompleted == false) event.done!.complete();
    result.when(
      ok: (HomeSnapshot snapshot) => emit(HomeReady(snapshot)),
      // The list on screen is still the last good one.
      err: (failure) {
        if (state is! HomeReady) emit(HomeFailure(failure.message));
      },
    );
  }
}
