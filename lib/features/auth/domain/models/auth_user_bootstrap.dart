import 'package:equatable/equatable.dart';
import '../../../../core/security/permission.dart';
import 'user_profile.dart';
import 'user_role.dart';

enum AccountStatus {
  active,
  inactive,
  suspended;

  static AccountStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'active':
        return AccountStatus.active;
      case 'inactive':
        return AccountStatus.inactive;
      case 'suspended':
        return AccountStatus.suspended;
      default:
        return AccountStatus.inactive;
    }
  }
}

class AuthUserBootstrap extends Equatable {
  final UserProfile profile;
  final UserRole role;
  final String? primaryBranchId;
  final AccountStatus accountStatus;
  final List<Permission> effectivePermissions;
  final String? studentId;
  final String? parentId;
  final String? teacherId;

  const AuthUserBootstrap({
    required this.profile,
    required this.role,
    this.primaryBranchId,
    required this.accountStatus,
    required this.effectivePermissions,
    this.studentId,
    this.parentId,
    this.teacherId,
  });

  bool hasPermission(Permission permission) {
    if (accountStatus != AccountStatus.active) return false;
    if (role == UserRole.superAdmin) return true;
    return effectivePermissions.contains(permission);
  }

  factory AuthUserBootstrap.fromJson(Map<String, dynamic> json) {
    final profJson = json['profile'] as Map<String, dynamic>;
    final profile = UserProfile.fromJson(profJson);
    final role = UserRole.fromString(json['canonical_role'] as String? ?? '');
    final status = AccountStatus.fromString(
      json['account_status'] as String? ?? 'active',
    );

    final rawPerms = json['effective_permissions'] as List<dynamic>? ?? [];
    final permissions = rawPerms
        .map((p) => Permission.fromCode(p as String))
        .whereType<Permission>()
        .toList();

    final domainId = json['domain_identity'] as Map<String, dynamic>? ?? {};

    return AuthUserBootstrap(
      profile: profile,
      role: role,
      primaryBranchId: json['primary_branch_id'] as String?,
      accountStatus: status,
      effectivePermissions: permissions,
      studentId: domainId['student_id'] as String?,
      parentId: domainId['parent_id'] as String?,
      teacherId: domainId['teacher_id'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    profile,
    role,
    primaryBranchId,
    accountStatus,
    effectivePermissions,
    studentId,
    parentId,
    teacherId,
  ];
}
