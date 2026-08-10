import 'package:flutter/material.dart';
import '../../../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/components/glass_card.dart';

class TeacherProfileScreen extends StatelessWidget {
  final AuthViewModel authViewModel;

  const TeacherProfileScreen({super.key, required this.authViewModel});

  @override
  Widget build(BuildContext context) {
    final user = authViewModel.currentUser;
    final bootstrap = authViewModel.bootstrap;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            FadeInSlide(
              child: GlassCard(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primarySubtle,
                      child: Icon(Icons.person, size: 48, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.fullName ?? 'Educator Teacher',
                      style: AppTypography.displaySmall(AppColors.darkTextPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'teacher@academy.com',
                      style: AppTypography.bodyMedium(AppColors.darkTextSecondary),
                    ),
                    const SizedBox(height: 16),
                    StatusChip(
                      label: 'ROLE: ${(user?.role ?? "teacher").toString().toUpperCase()}',
                      status: ChipStatus.purple,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeInSlide(
              delay: const Duration(milliseconds: 100),
              child: GlassCard(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Specifications',
                      style: AppTypography.titleLarge(AppColors.darkTextPrimary),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleIcon(icon: Icons.badge, color: AppColors.info),
                      title: Text('Teacher Domain ID', style: AppTypography.titleMedium(AppColors.darkTextPrimary)),
                      subtitle: Text(bootstrap?.teacherId ?? 'Not provisioned', style: AppTypography.bodySmall(AppColors.darkTextSecondary)),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleIcon(icon: Icons.domain, color: AppColors.warning),
                      title: Text('Primary Branch ID', style: AppTypography.titleMedium(AppColors.darkTextPrimary)),
                      subtitle: Text(user?.branchId ?? 'Not assigned', style: AppTypography.bodySmall(AppColors.darkTextSecondary)),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleIcon(icon: Icons.security, color: AppColors.success),
                      title: Text('Effective Permissions', style: AppTypography.titleMedium(AppColors.darkTextPrimary)),
                      subtitle: Text(
                        '${bootstrap?.effectivePermissions.length ?? 0} active system permissions',
                        style: AppTypography.bodySmall(AppColors.darkTextSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeInSlide(
              delay: const Duration(milliseconds: 200),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => authViewModel.signOut(),
                icon: const Icon(Icons.logout),
                label: Text('Sign Out', style: AppTypography.labelLarge(Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
