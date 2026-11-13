import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/utils/app_log.dart';

/// Logs that a bloc was created, changed or closed. It names the types only.
/// Events and states hold patient data, so their values are never printed.
class AppBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase<dynamic> bloc) {
    AppLog.line('[BLOC] created → ${bloc.runtimeType}');
    super.onCreate(bloc);
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    AppLog.line('[BLOC] event  → ${bloc.runtimeType} | ${event.runtimeType}');
    super.onEvent(bloc, event);
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    AppLog.line(
      '[BLOC] state  → ${bloc.runtimeType} | '
      '${change.currentState.runtimeType} → ${change.nextState.runtimeType}',
    );
    super.onChange(bloc, change);
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    // The error type only: its text can quote what the user typed.
    AppLog.line('[BLOC] error  → ${bloc.runtimeType} | ${error.runtimeType}');
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    AppLog.line('[BLOC] closed → ${bloc.runtimeType}');
    super.onClose(bloc);
  }
}
