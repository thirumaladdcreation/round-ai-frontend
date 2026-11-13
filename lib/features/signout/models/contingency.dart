import 'package:equatable/equatable.dart';

/// An "if ... then ..." the clinician wrote for the night team. The sign-out
/// never makes these up.
class Contingency extends Equatable {
  const Contingency({required this.condition, required this.action});

  final String condition;
  final String action;

  Map<String, String> toJson() => <String, String>{
    'if': condition.trim(),
    'then': action.trim(),
  };

  @override
  List<Object> get props => <Object>[condition, action];
}
