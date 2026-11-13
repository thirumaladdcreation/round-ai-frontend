import 'dart:async';

import 'package:equatable/equatable.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object> get props => <Object>[];
}

class HomeRequested extends HomeEvent {
  const HomeRequested();
}

/// Pull-to-refresh. The list stays on screen while it reloads, and a failed
/// reload leaves the last list as it was.
class HomeRefreshed extends HomeEvent {
  const HomeRefreshed({this.done});

  /// Completed when the reload has finished.
  final Completer<void>? done;
}
