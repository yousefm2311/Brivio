import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/errors/failures.dart';
import 'package:flutter_application_1/features/auth/domain/models/auth_user_bootstrap.dart';
import 'package:flutter_application_1/features/auth/domain/models/user_profile.dart';
import 'package:flutter_application_1/features/auth/domain/models/user_role.dart';
import 'package:flutter_application_1/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:flutter_application_1/features/auth/presentation/viewmodels/auth_viewmodel.dart';

class MockFailingAuthRepository implements IAuthRepository {
  final Failure failureToThrow;
  MockFailingAuthRepository(this.failureToThrow);

  @override
  Future<UserProfile?> getCurrentUser() async => null;

  @override
  Future<AuthUserBootstrap> fetchUserBootstrap() async {
    throw failureToThrow;
  }

  @override
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    throw failureToThrow;
  }

  @override
  Future<UserProfile> signInWithMagicQr({
    required String email,
    required String token,
  }) async {
    throw failureToThrow;
  }

  @override
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    throw failureToThrow;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    throw failureToThrow;
  }

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<Map<String, dynamic>> provisionPrivilegedUser({
    required String email,
    required String fullName,
    required UserRole role,
    String? branchId,
  }) async {
    throw failureToThrow;
  }
}

class MockSuspendedAuthRepository implements IAuthRepository {
  final UserProfile _user = UserProfile(
    id: 'suspended-user-id',
    email: 'suspended@academy.com',
    fullName: 'Suspended User',
    role: UserRole.student,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  Future<UserProfile?> getCurrentUser() async => _user;

  @override
  Future<AuthUserBootstrap> fetchUserBootstrap() async {
    return AuthUserBootstrap(
      profile: _user,
      role: UserRole.student,
      accountStatus: AccountStatus.suspended,
      effectivePermissions: const [],
      studentId: 'suspended-student-id',
    );
  }

  @override
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) async => _user;

  @override
  Future<UserProfile> signInWithMagicQr({
    required String email,
    required String token,
  }) async => _user;

  @override
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async => _user;

  @override
  Future<void> signOut() async {}

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async => profile;

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<Map<String, dynamic>> provisionPrivilegedUser({
    required String email,
    required String fullName,
    required UserRole role,
    String? branchId,
  }) async => {};
}

void main() {
  group('Production Integration Auth Tests', () {
    test(
      'signIn fails on empty credentials without calling repository',
      () async {
        final repo = MockFailingAuthRepository(
          const AuthFailure(message: 'Invalid credentials'),
        );
        final vm = AuthViewModel(repo);

        await vm.signIn(email: '', password: '');
        expect(vm.state.status, AuthStatus.error);
        expect(vm.state.failure, isA<ValidationFailure>());
        expect(vm.isAuthenticated, isFalse);
      },
    );

    test('signIn maps AuthFailure on invalid credentials exception', () async {
      final repo = MockFailingAuthRepository(
        const AuthFailure(message: 'Invalid login credentials'),
      );
      final vm = AuthViewModel(repo);

      await vm.signIn(email: 'wrong@academy.com', password: 'wrongpassword');
      expect(vm.state.status, AuthStatus.error);
      expect(vm.state.failure?.message, 'Invalid login credentials');
      expect(vm.isAuthenticated, isFalse);
    });

    test(
      'restoreSession sets unauthenticated state when no session exists',
      () async {
        final repo = MockFailingAuthRepository(
          const AuthFailure(message: 'No session'),
        );
        final vm = AuthViewModel(repo);

        await vm.restoreSession();
        expect(vm.state.status, AuthStatus.unauthenticated);
        expect(vm.isAuthenticated, isFalse);
      },
    );

    test(
      'suspended user account status results in AuthStatus.restricted state',
      () async {
        final repo = MockSuspendedAuthRepository();
        final vm = AuthViewModel(repo);

        await vm.restoreSession();
        expect(vm.state.status, AuthStatus.restricted);
        expect(vm.isAuthenticated, isFalse);
        expect(vm.isRestricted, isTrue);
      },
    );

    test(
      'signOut resets state to unauthenticated and clears auth user state',
      () async {
        final repo = MockSuspendedAuthRepository();
        final vm = AuthViewModel(repo);

        await vm.restoreSession();
        expect(vm.isRestricted, isTrue);

        await vm.signOut();
        expect(vm.state.status, AuthStatus.unauthenticated);
        expect(vm.isAuthenticated, isFalse);
        expect(vm.currentUser, isNull);
      },
    );
  });
}
