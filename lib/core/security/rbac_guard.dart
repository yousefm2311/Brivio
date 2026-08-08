import 'package:flutter/material.dart';
import '../../features/auth/domain/models/auth_user_bootstrap.dart';
import '../../features/auth/domain/models/user_role.dart';
import 'permission.dart';

/// RbacGuard (UI Navigation & UX Visibility Gate ONLY)
///
/// NOTE: This class MUST NOT be considered an authorization security boundary.
/// All backend authorization MUST be enforced by PostgreSQL RLS, storage policies,
/// or server-side RPC functions.
class RbacGuard {
  /// Simple role check helper for UI navigation.
  static bool hasPermission(UserRole role, List<UserRole> allowedRoles) {
    if (role == UserRole.superAdmin || role == UserRole.admin) {
      return true;
    }
    return allowedRoles.contains(role);
  }

  /// UI Widget Guard: Renders child if userRole is allowed, otherwise displays Access Denied screen.
  static Widget protect({
    required UserRole userRole,
    required List<UserRole> allowedRoles,
    required Widget child,
  }) {
    if (hasPermission(userRole, allowedRoles)) {
      return child;
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gpp_bad_rounded, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Access Denied: Wrong Portal',
              style: ThemeData.light().textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Your account role (${userRole.displayName}) is not authorized for this portal.',
              style: ThemeData.light().textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  /// Check whether the user role is authorized to access a given portal UI route.
  static bool isRouteAllowedForRole({
    required UserRole role,
    required String routePath,
  }) {
    if (role == UserRole.superAdmin || role == UserRole.admin) {
      return true;
    }

    if (routePath.startsWith('/student') && role == UserRole.student) {
      return true;
    }
    if (routePath.startsWith('/parent') && role == UserRole.parent) {
      return true;
    }
    if (routePath.startsWith('/teacher') && role == UserRole.teacher) {
      return true;
    }
    if (routePath.startsWith('/staff') && role == UserRole.staff) {
      return true;
    }

    return false;
  }

  /// Verify whether the authenticated bootstrap state permits access to target portal path.
  static bool canAccessPortal({
    required AuthUserBootstrap? bootstrap,
    required String targetPortalPrefix,
  }) {
    if (bootstrap == null) return false;
    if (bootstrap.accountStatus != AccountStatus.active) return false;

    final role = bootstrap.role;
    if (role == UserRole.superAdmin || role == UserRole.admin) return true;

    switch (targetPortalPrefix) {
      case 'student':
        return role == UserRole.student;
      case 'parent':
        return role == UserRole.parent;
      case 'teacher':
        return role == UserRole.teacher;
      case 'staff':
        return role == UserRole.staff;
      case 'admin':
        return role == UserRole.admin || role == UserRole.superAdmin;
      default:
        return false;
    }
  }

  /// Verify whether the user possesses a specific granular capability permission.
  static bool hasEffectivePermission({
    required AuthUserBootstrap? bootstrap,
    required Permission permission,
  }) {
    if (bootstrap == null) return false;
    return bootstrap.hasPermission(permission);
  }
}
