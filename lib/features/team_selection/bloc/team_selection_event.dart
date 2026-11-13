import 'package:equatable/equatable.dart';

sealed class TeamSelectionEvent extends Equatable {
  const TeamSelectionEvent();

  @override
  List<Object> get props => <Object>[];
}

class TeamSelectionStarted extends TeamSelectionEvent {
  const TeamSelectionStarted();
}

class TeamChosen extends TeamSelectionEvent {
  const TeamChosen(this.teamId);

  final String teamId;

  @override
  List<Object> get props => <Object>[teamId];
}

class TeamContinuePressed extends TeamSelectionEvent {
  const TeamContinuePressed();
}
