import 'package:equatable/equatable.dart';

class AuthState extends Equatable {
  const AuthState({this.loading = false, this.error, this.signedIn = false});

  final bool loading;
  final String? error;
  final bool signedIn;

  AuthState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    bool? signedIn,
  }) {
    return AuthState(
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      signedIn: signedIn ?? this.signedIn,
    );
  }

  @override
  List<Object?> get props => <Object?>[loading, error, signedIn];
}
