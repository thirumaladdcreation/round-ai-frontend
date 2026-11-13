import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => <Object>[];
}

class AuthSignInSubmitted extends AuthEvent {
  const AuthSignInSubmitted({
    required this.email,
    required this.password,
    required this.rememberMe,
  });

  final String email;
  final String password;
  final bool rememberMe;

  @override
  List<Object> get props => <Object>[email, password, rememberMe];
}
