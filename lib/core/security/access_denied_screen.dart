import 'package:flutter/material.dart';
import '../../design_system/components/buttons.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/tokens/typography.dart';
import '../../features/auth/domain/models/user_role.dart';

/// Screen displayed when an RBAC permission check fails.
class AccessDeniedScreen extends StatelessWidget {
  final UserRole currentRole;
  final List<UserRole> requiredRoles;

  const AccessDeniedScreen({
    super.key,
    required this.currentRole,
    required this.requiredRoles,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final rolesString = requiredRoles.map((r) => r.displayName).join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Access Restricted')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_person_rounded,
                    size: 56,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Access Denied',
                  style: AppTypography.displayMedium(textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your current role (${currentRole.displayName}) does not have permission to view this resource. Requires: $rolesString.',
                  style: AppTypography.bodyLarge(textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  child: PrimaryButton(
                    text: 'Return to Home',
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: Icons.arrow_back_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen displayed when an authenticated user attempts to access an unauthorized target portal application.
class PortalDeniedScreen extends StatelessWidget {
  final UserRole? currentRole;
  final String targetPortalName;
  final VoidCallback onSignOut;

  const PortalDeniedScreen({
    super.key,
    required this.currentRole,
    required this.targetPortalName,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final roleName = currentRole?.displayName ?? 'Unassigned';

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gpp_bad_rounded,
                    size: 64,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Portal Access Denied',
                  style: AppTypography.displayMedium(textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your authenticated role ($roleName) is not authorized to access the $targetPortalName.',
                  style: AppTypography.bodyLarge(textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  child: PrimaryButton(
                    text: 'Sign Out',
                    onPressed: onSignOut,
                    icon: Icons.logout_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen displayed when an authenticated account is suspended, inactive, or restricted.
class AccountRestrictedScreen extends StatelessWidget {
  final VoidCallback onSignOut;

  const AccountRestrictedScreen({super.key, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    size: 64,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Account Restricted',
                  style: AppTypography.displayMedium(textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your user account status is inactive or suspended. Please contact your academy administrator.',
                  style: AppTypography.bodyLarge(textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  child: PrimaryButton(
                    text: 'Sign Out',
                    onPressed: onSignOut,
                    icon: Icons.logout_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
