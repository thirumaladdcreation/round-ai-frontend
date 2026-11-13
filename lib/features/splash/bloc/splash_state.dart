import 'package:equatable/equatable.dart';

sealed class SplashState extends Equatable {
  const SplashState();
}

class SplashWaiting extends SplashState {
  const SplashWaiting();

  @override
  List<Object?> get props => <Object?>[];
}

/// The saved session could not be checked, for example offline.
class SplashFailed extends SplashState {
  const SplashFailed(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

class SplashReady extends SplashState {
  const SplashReady(this.route);

  final String route;

  @override
  List<Object?> get props => <Object?>[route];
}
