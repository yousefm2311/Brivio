import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/security/rbac_guard.dart';
import 'package:flutter_application_1/features/auth/domain/models/user_role.dart';

void main() {
  group('RbacGuard UI Navigation Tests', () {
    test('Student role is restricted to student routes in UI', () {
      expect(
        RbacGuard.hasPermission(UserRole.student, [UserRole.student]),
        isTrue,
      );
      expect(
        RbacGuard.hasPermission(UserRole.student, [UserRole.teacher]),
        isFalse,
      );
      expect(
        RbacGuard.hasPermission(UserRole.student, [UserRole.staff]),
        isFalse,
      );
      expect(
        RbacGuard.hasPermission(UserRole.student, [UserRole.admin]),
        isFalse,
      );
    });

    test('Staff role can access staff routes in UI', () {
      expect(RbacGuard.hasPermission(UserRole.staff, [UserRole.staff]), isTrue);
      expect(
        RbacGuard.hasPermission(UserRole.staff, [UserRole.teacher]),
        isFalse,
      );
    });

    test('Teacher role can access teacher routes in UI', () {
      expect(
        RbacGuard.hasPermission(UserRole.teacher, [UserRole.teacher]),
        isTrue,
      );
      expect(
        RbacGuard.hasPermission(UserRole.teacher, [UserRole.staff]),
        isFalse,
      );
    });

    test('Admin and SuperAdmin have cross-domain UI permission', () {
      expect(
        RbacGuard.hasPermission(UserRole.admin, [UserRole.student]),
        isTrue,
      );
      expect(RbacGuard.hasPermission(UserRole.admin, [UserRole.staff]), isTrue);
      expect(
        RbacGuard.hasPermission(UserRole.superAdmin, [UserRole.admin]),
        isTrue,
      );
      expect(
        RbacGuard.hasPermission(UserRole.superAdmin, [UserRole.teacher]),
        isTrue,
      );
    });
  });
}
