import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/domain/models/user_role.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'permission.dart';

/// PermissionGate Widget
/// Renders child widget if current authenticated user has the specified permission.
class PermissionGate extends ConsumerWidget {
  final Permission permission;
  final Widget child;
  final Widget fallback;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authViewModelProvider).state;
    if (authState.hasPermission(permission)) {
      return child;
    }
    return fallback;
  }
}

/// RoleGate Widget
/// Renders child widget if current authenticated user has one of the allowed roles.
class RoleGate extends ConsumerWidget {
  final List<UserRole> allowedRoles;
  final Widget child;
  final Widget fallback;

  const RoleGate({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authViewModelProvider).state;
    final role = authState.role;
    if (role != null &&
        (allowedRoles.contains(role) || role == UserRole.superAdmin)) {
      return child;
    }
    return fallback;
  }
}

final authViewModelProvider = ChangeNotifierProvider<AuthViewModel>((ref) {
  throw UnimplementedError(
    'authViewModelProvider must be overridden in ProviderScope',
  );
});
