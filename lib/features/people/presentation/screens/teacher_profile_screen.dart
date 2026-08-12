import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../features/auth/presentation/viewmodels/auth_viewmodel.dart';

class TeacherProfileScreen extends StatefulWidget {
  final AuthViewModel authViewModel;

  const TeacherProfileScreen({super.key, required this.authViewModel});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _avatarController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.authViewModel.currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _avatarController = TextEditingController(text: user?.avatarUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    await widget.authViewModel.updateProfile(
      fullName: _nameController.text,
      phoneNumber: _phoneController.text,
      avatarUrl: _avatarController.text,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    final failure = widget.authViewModel.state.failure;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure?.message ?? 'Profile updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authViewModel.currentUser;
    final bootstrap = widget.authViewModel.bootstrap;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            FadeInSlide(
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primarySubtle,
                        backgroundImage: (_avatarController.text.trim().isEmpty)
                            ? null
                            : NetworkImage(_avatarController.text.trim()),
                        child: _avatarController.text.trim().isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 48,
                                color: AppColors.primary,
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _avatarController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Avatar URL',
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Save profile'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeInSlide(
              delay: const Duration(milliseconds: 100),
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Specifications',
                      style: AppTypography.titleLarge(
                        AppColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleIcon(
                        icon: Icons.badge,
                        color: AppColors.info,
                      ),
                      title: Text(
                        'Teacher Domain ID',
                        style: AppTypography.titleMedium(
                          AppColors.darkTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        bootstrap?.teacherId ?? 'Not provisioned',
                        style: AppTypography.bodySmall(
                          AppColors.darkTextSecondary,
                        ),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleIcon(
                        icon: Icons.email_outlined,
                        color: AppColors.warning,
                      ),
                      title: Text(
                        'Email',
                        style: AppTypography.titleMedium(
                          AppColors.darkTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        user?.email ?? 'teacher@academy.com',
                        style: AppTypography.bodySmall(
                          AppColors.darkTextSecondary,
                        ),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleIcon(
                        icon: Icons.security,
                        color: AppColors.success,
                      ),
                      title: Text(
                        'Effective Permissions',
                        style: AppTypography.titleMedium(
                          AppColors.darkTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${bootstrap?.effectivePermissions.length ?? 0} active system permissions',
                        style: AppTypography.bodySmall(
                          AppColors.darkTextSecondary,
                        ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => widget.authViewModel.signOut(),
                icon: const Icon(Icons.logout),
                label: Text(
                  'Sign Out',
                  style: AppTypography.labelLarge(Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
