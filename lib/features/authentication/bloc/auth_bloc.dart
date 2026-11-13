import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/authentication/bloc/auth_event.dart';
import 'package:round_ai/features/authentication/bloc/auth_state.dart';
import 'package:round_ai/features/authentication/repository/auth_repository.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(const AuthState()) {
    on<AuthSignInSubmitted>(_onSubmit);
  }

  final AuthRepository _repository;

  Future<void> _onSubmit(
    AuthSignInSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(loading: true, clearError: true, signedIn: false));
    final Result<void> result = await _repository.signIn(
      email: event.email,
      password: event.password,
      rememberMe: event.rememberMe,
    );
    result.when(
      ok: (_) => emit(
        state.copyWith(loading: false, clearError: true, signedIn: true),
      ),
      err: (failure) => emit(
        state.copyWith(loading: false, error: failure.message, signedIn: false),
      ),
    );
  }
}
