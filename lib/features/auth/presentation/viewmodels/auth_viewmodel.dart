import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/core/errors/failures.dart';
import 'package:flutter_application_1/core/security/permission.dart';
import 'package:flutter_application_1/features/auth/domain/models/auth_user_bootstrap.dart';
import 'package:flutter_application_1/features/auth/domain/models/user_profile.dart';
import 'package:flutter_application_1/features/auth/domain/models/user_role.dart';
import 'package:flutter_application_1/features/auth/domain/repositories/i_auth_repository.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  restricted,
  error,
}

class AuthState {
  final AuthStatus status;
  final AuthUserBootstrap? bootstrap;
  final Failure? failure;

  const AuthState({required this.status, this.bootstrap, this.failure});

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);
  factory AuthState.unauthenticated() =>
      const AuthState(status: AuthStatus.unauthenticated);
  factory AuthState.authenticated(AuthUserBootstrap bootstrap) => AuthState(
    status: bootstrap.accountStatus == AccountStatus.suspended
        ? AuthStatus.restricted
        : AuthStatus.authenticated,
    bootstrap: bootstrap,
  );
  factory AuthState.restricted(AuthUserBootstrap bootstrap) =>
      AuthState(status: AuthStatus.restricted, bootstrap: bootstrap);
  factory AuthState.error(Failure failure) =>
      AuthState(status: AuthStatus.error, failure: failure);

  UserProfile? get profile => bootstrap?.profile;
  UserRole? get role => bootstrap?.role;
  AccountStatus? get accountStatus => bootstrap?.accountStatus;

  bool hasPermission(Permission permission) {
    if (bootstrap == null) return false;
    return bootstrap!.hasPermission(permission);
  }
}

class AuthViewModel extends ChangeNotifier {
  final IAuthRepository _authRepository;
  AuthState _state = AuthState.initial();
  bool _isRestoringSession = false;

  AuthViewModel(this._authRepository);

  AuthState get state => _state;
  UserProfile? get currentUser => _state.profile;
  AuthUserBootstrap? get bootstrap => _state.bootstrap;
  UserRole? get userRole => _state.role;
  bool get isAuthenticated => _state.status == AuthStatus.authenticated;
  bool get isRestricted => _state.status == AuthStatus.restricted;

  /// Single-flight session restoration preventing race conditions & duplicate requests
  Future<void> restoreSession() async {
    if (_isRestoringSession) return;
    _isRestoringSession = true;

    _state = AuthState.loading();
    notifyListeners();

    try {
      final user = await _authRepository.getCurrentUser();
      if (user == null) {
        _state = AuthState.unauthenticated();
      } else {
        final bootstrap = await _authRepository.fetchUserBootstrap();
        _state = AuthState.authenticated(bootstrap);
      }
    } on Failure catch (f) {
      _state = AuthState.error(f);
    } catch (e) {
      _state = AuthState.error(UnexpectedFailure(message: e.toString()));
    } finally {
      _isRestoringSession = false;
    }
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      _state = AuthState.error(
        const ValidationFailure(message: 'Email and password cannot be empty.'),
      );
      notifyListeners();
      return;
    }

    _state = AuthState.loading();
    notifyListeners();

    try {
      await _authRepository.signInWithEmail(
        email: email.trim(),
        password: password,
      );
      final bootstrap = await _authRepository.fetchUserBootstrap();
      _state = AuthState.authenticated(bootstrap);
    } on Failure catch (f) {
      _state = AuthState.error(f);
    } catch (e) {
      _state = AuthState.error(UnexpectedFailure(message: e.toString()));
    }
    notifyListeners();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (email.trim().isEmpty ||
        password.trim().isEmpty ||
        fullName.trim().isEmpty) {
      _state = AuthState.error(
        const ValidationFailure(message: 'All fields are required.'),
      );
      notifyListeners();
      return;
    }

    _state = AuthState.loading();
    notifyListeners();

    try {
      await _authRepository.signUpWithEmail(
        email: email.trim(),
        password: password,
        fullName: fullName.trim(),
      );
      final bootstrap = await _authRepository.fetchUserBootstrap();
      _state = AuthState.authenticated(bootstrap);
    } on Failure catch (f) {
      _state = AuthState.error(f);
    } catch (e) {
      _state = AuthState.error(UnexpectedFailure(message: e.toString()));
    }
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) async {
    if (email.trim().isEmpty) {
      _state = AuthState.error(
        const ValidationFailure(
          message: 'Email is required for password reset.',
        ),
      );
      notifyListeners();
      return;
    }

    try {
      await _authRepository.sendPasswordResetEmail(email.trim());
    } on Failure catch (f) {
      _state = AuthState.error(f);
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _state = AuthState.loading();
    notifyListeners();

    try {
      await _authRepository.signOut();
      _state = AuthState.unauthenticated();
    } on Failure catch (f) {
      _state = AuthState.error(f);
    } catch (e) {
      _state = AuthState.error(UnexpectedFailure(message: e.toString()));
    }
    notifyListeners();
  }
}
