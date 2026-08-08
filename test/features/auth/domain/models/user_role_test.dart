import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/domain/models/user_role.dart';

void main() {
  group('UserRole Reconciliation Tests', () {
    test('fromString parses all 6 canonical roles correctly', () {
      expect(UserRole.fromString('super_admin'), UserRole.superAdmin);
      expect(UserRole.fromString('superadmin'), UserRole.superAdmin);
      expect(UserRole.fromString('super-admin'), UserRole.superAdmin);
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('staff'), UserRole.staff);
      expect(UserRole.fromString('teacher'), UserRole.teacher);
      expect(UserRole.fromString('parent'), UserRole.parent);
      expect(UserRole.fromString('student'), UserRole.student);
    });

    test('fromString returns unknown for invalid role strings', () {
      expect(UserRole.fromString('hacker_role'), UserRole.unknown);
      expect(UserRole.fromString(''), UserRole.unknown);
    });

    test('toDbValue outputs exact canonical PostgreSQL enum strings', () {
      expect(UserRole.superAdmin.toDbValue(), 'super_admin');
      expect(UserRole.admin.toDbValue(), 'admin');
      expect(UserRole.staff.toDbValue(), 'staff');
      expect(UserRole.teacher.toDbValue(), 'teacher');
      expect(UserRole.parent.toDbValue(), 'parent');
      expect(UserRole.student.toDbValue(), 'student');
      expect(UserRole.unknown.toDbValue(), 'unknown');
    });

    test('displayName returns human-readable titles for all roles', () {
      expect(UserRole.superAdmin.displayName, 'Super Administrator');
      expect(UserRole.admin.displayName, 'Branch Administrator');
      expect(UserRole.staff.displayName, 'Operations Staff');
      expect(UserRole.teacher.displayName, 'Teacher');
      expect(UserRole.parent.displayName, 'Parent');
      expect(UserRole.student.displayName, 'Student');
    });
  });
}
