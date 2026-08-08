import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/security/permission.dart';
import 'package:flutter_application_1/features/auth/domain/models/user_role.dart';
import 'package:flutter_application_1/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:flutter_application_1/core/testing/dummy_auth_repository.dart';

void main() {
  late DummyAuthRepository mockAuthRepository;
  late AuthViewModel viewModel;

  setUp(() {
    mockAuthRepository = DummyAuthRepository();
    viewModel = AuthViewModel(mockAuthRepository);
  });

  group('AuthViewModel Unit Tests', () {
    test('initial state is AuthStatus.initial', () {
      expect(viewModel.state.status, AuthStatus.initial);
      expect(viewModel.isAuthenticated, isFalse);
    });

    test(
      'restoreSession updates state to authenticated with bootstrap',
      () async {
        await viewModel.restoreSession();

        expect(viewModel.state.status, AuthStatus.authenticated);
        expect(viewModel.isAuthenticated, isTrue);
        expect(viewModel.userRole, UserRole.student);
        expect(viewModel.state.hasPermission(Permission.studentsView), isTrue);
      },
    );

    test('signIn sets ValidationFailure on empty credentials', () async {
      await viewModel.signIn(email: '', password: '');

      expect(viewModel.state.status, AuthStatus.error);
      expect(viewModel.state.failure, isNotNull);
    });

    test(
      'signIn updates state to authenticated on successful sign in',
      () async {
        await viewModel.signIn(
          email: 'test@academy.com',
          password: 'password123',
        );

        expect(viewModel.state.status, AuthStatus.authenticated);
        expect(viewModel.isAuthenticated, isTrue);
      },
    );

    test('signOut updates state to unauthenticated', () async {
      await viewModel.restoreSession();
      expect(viewModel.isAuthenticated, isTrue);

      await viewModel.signOut();
      expect(viewModel.state.status, AuthStatus.unauthenticated);
      expect(viewModel.isAuthenticated, isFalse);
    });
  });
}
