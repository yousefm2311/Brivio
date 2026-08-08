/// Strongly typed role enumeration for RBAC enforcement.
/// Canonical role values: super_admin, admin, staff, teacher, parent, student.
enum UserRole {
  superAdmin,
  admin,
  staff,
  teacher,
  parent,
  student,
  unknown;

  static UserRole fromString(String value) {
    final sanitized = value.toLowerCase().trim();
    switch (sanitized) {
      case 'super_admin':
      case 'superadmin':
      case 'super-admin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'staff':
        return UserRole.staff;
      case 'teacher':
        return UserRole.teacher;
      case 'parent':
        return UserRole.parent;
      case 'student':
        return UserRole.student;
      default:
        return UserRole.unknown;
    }
  }

  String toDbValue() {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.admin:
        return 'admin';
      case UserRole.staff:
        return 'staff';
      case UserRole.teacher:
        return 'teacher';
      case UserRole.parent:
        return 'parent';
      case UserRole.student:
        return 'student';
      case UserRole.unknown:
        return 'unknown';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Administrator';
      case UserRole.admin:
        return 'Branch Administrator';
      case UserRole.staff:
        return 'Operations Staff';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.parent:
        return 'Parent';
      case UserRole.student:
        return 'Student';
      case UserRole.unknown:
        return 'User';
    }
  }
}
