import 'package:equatable/equatable.dart';

/// Base application failure contract.
abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final dynamic originalException;

  const Failure({required this.message, this.code, this.originalException});

  @override
  List<Object?> get props => [message, code, originalException];

  @override
  String toString() => '$runtimeType(message: $message, code: $code)';
}

/// Authentication failures (login, registration, invalid tokens, session expiry).
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.code,
    super.originalException,
  });
}

/// Permission & RBAC access failures.
class PermissionFailure extends Failure {
  const PermissionFailure({
    required super.message,
    super.code,
    super.originalException,
  });
}

/// Network connectivity or server failure.
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code,
    super.originalException,
  });
}

/// Database/Supabase query or schema failure.
class DatabaseFailure extends Failure {
  const DatabaseFailure({
    required super.message,
    super.code,
    super.originalException,
  });
}

/// Validation failure for invalid client inputs.
class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;

  const ValidationFailure({
    required super.message,
    this.fieldErrors,
    super.code,
    super.originalException,
  });

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

/// Generic unexpected failure.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    required super.message,
    super.code,
    super.originalException,
  });
}
