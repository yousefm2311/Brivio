import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/security/permission.dart';
import 'package:flutter_application_1/core/security/permission_gate.dart';
import 'package:flutter_application_1/features/auth/domain/models/user_role.dart';
import 'package:flutter_application_1/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:flutter_application_1/core/testing/dummy_auth_repository.dart';

void main() {
  late DummyAuthRepository dummyRepo;
  late AuthViewModel authViewModel;

  setUp(() {
    dummyRepo = DummyAuthRepository();
    authViewModel = AuthViewModel(dummyRepo);
  });

  Widget buildTestApp(Widget gateWidget) {
    return ProviderScope(
      overrides: [authViewModelProvider.overrideWith((ref) => authViewModel)],
      child: MaterialApp(home: Scaffold(body: gateWidget)),
    );
  }

  group('PermissionGate & RoleGate Widget Tests', () {
    testWidgets('PermissionGate renders child when permission is granted', (
      tester,
    ) async {
      await authViewModel.restoreSession();

      await tester.pumpWidget(
        buildTestApp(
          const PermissionGate(
            permission: Permission.studentsView,
            fallback: Text('FALLBACK_CONTENT'),
            child: Text('ALLOWED_CONTENT'),
          ),
        ),
      );

      expect(find.text('ALLOWED_CONTENT'), findsOneWidget);
    });

    testWidgets('RoleGate renders child when role matches allowed roles', (
      tester,
    ) async {
      await authViewModel.restoreSession();

      await tester.pumpWidget(
        buildTestApp(
          const RoleGate(
            allowedRoles: [UserRole.student],
            fallback: Text('DENIED_PORTAL_CONTENT'),
            child: Text('STUDENT_PORTAL_CONTENT'),
          ),
        ),
      );

      expect(find.text('STUDENT_PORTAL_CONTENT'), findsOneWidget);
    });
  });
}
