import 'package:equatable/equatable.dart';
import 'package:round_ai/core/network/api_error.dart';

sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object> get props => <Object>[message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;

  @override
  List<Object> get props => <Object>[message, statusCode ?? 0];
}

/// A backend error. [message] is safe to show: it is the app's own wording,
/// not text from the server. Screens read [error] to react to its kind.
class ApiFailure extends Failure {
  ApiFailure(this.error) : super(error.userMessage);

  final ApiError error;

  @override
  List<Object> get props => <Object>[message, error.code, error.status ?? 0];
}

/// The [ApiError] behind a failure, so screens can react to its kind.
/// Anything that is not an API failure reads as "something went wrong".
extension FailureApiError on Failure {
  ApiError get apiError {
    final Failure self = this;
    if (self is ApiFailure) return self.error;
    return const ApiError(code: 'unknown_error', message: '');
  }
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}
