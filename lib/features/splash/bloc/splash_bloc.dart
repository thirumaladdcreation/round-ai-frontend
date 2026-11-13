import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/splash/bloc/splash_event.dart';
import 'package:round_ai/features/splash/bloc/splash_state.dart';
import 'package:round_ai/features/splash/repository/splash_repository.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  SplashBloc(this._repository) : super(const SplashWaiting()) {
    on<SplashStarted>(_onStarted);
  }

  final SplashRepository _repository;

  /// The splash artwork already shows the loading line.
  /// The pause only keeps the brand readable before routing.
  static const Duration hold = Duration(milliseconds: 1600);

  /// Also used for Retry.
  Future<void> _onStarted(
    SplashStarted event,
    Emitter<SplashState> emit,
  ) async {
    emit(const SplashWaiting());
    final Future<void> pause = Future<void>.delayed(hold);
    final Result<String> result = await _repository.destination();
    await pause;
    if (isClosed) return;
    switch (result) {
      case Ok<String>(:final value):
        emit(SplashReady(value));
      case Err<String>(:final failure):
        emit(SplashFailed(failure.message));
    }
  }
}
