import 'package:flutter/material.dart';
import '../../../../design_system/components/buttons.dart';
import '../../../../design_system/components/cards.dart';
import '../../../../design_system/components/text_fields.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../viewmodels/profile_viewmodel.dart';

class ProfileScreen extends StatefulWidget {
  final ProfileViewModel viewModel;
  final VoidCallback? onSignedOut;

  const ProfileScreen({super.key, required this.viewModel, this.onSignedOut});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _avatarController;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profile = widget.viewModel.currentProfile;
    _nameController = TextEditingController(text: profile?.fullName ?? '');
    _phoneController = TextEditingController(text: profile?.phoneNumber ?? '');
    _avatarController = TextEditingController(text: profile?.avatarUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _avatarController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.viewModel.updateProfileDetails(
        fullName: _nameController.text,
        phoneNumber: _phoneController.text.isNotEmpty
            ? _phoneController.text
            : null,
        avatarUrl: _avatarController.text.isNotEmpty
            ? _avatarController.text
            : null,
      );
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: CustomTextField(
            label: 'New Password',
            hint: 'At least 6 characters',
            controller: _passwordController,
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_passwordController.text.length >= 6) {
                  widget.viewModel.updatePassword(_passwordController.text);
                  Navigator.pop(context);
                  _passwordController.clear();
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final state = widget.viewModel.state;
        final profile = state.profile;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Account Profile'),
            actions: [
              if (widget.onSignedOut != null)
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                  ),
                  onPressed: widget.onSignedOut,
                  tooltip: 'Sign Out',
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Avatar Header
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.15,
                        ),
                        backgroundImage:
                            profile?.avatarUrl != null &&
                                profile!.avatarUrl!.isNotEmpty
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child:
                            profile?.avatarUrl == null ||
                                profile!.avatarUrl!.isEmpty
                            ? Text(
                                profile?.fullName.isNotEmpty == true
                                    ? profile!.fullName[0].toUpperCase()
                                    : 'U',
                                style: AppTypography.displayLarge(
                                  AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile?.fullName ?? 'User',
                        style: AppTypography.titleLarge(textPrimary),
                      ),
                      Text(
                        '${profile?.role.displayName} • ${profile?.email ?? ''}',
                        style: AppTypography.bodyMedium(textSecondary),
                      ),
                      const SizedBox(height: 32),

                      if (state.status == ProfileStatus.success &&
                          state.message != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            state.message!,
                            style: AppTypography.bodyMedium(AppColors.success),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      CustomCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTextField(
                              label: 'Full Name',
                              controller: _nameController,
                              prefixIcon: Icons.person_outline,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Name is required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: 'Phone Number',
                              hint: '+1 234 567 8900',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_outlined,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: 'Avatar Image URL',
                              hint: 'https://example.com/avatar.png',
                              controller: _avatarController,
                              prefixIcon: Icons.image_outlined,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      PrimaryButton(
                        text: 'Save Changes',
                        isLoading: state.status == ProfileStatus.loading,
                        onPressed: _saveProfile,
                        icon: Icons.save_rounded,
                      ),
                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        onPressed: () => _showChangePasswordDialog(context),
                        icon: const Icon(Icons.key_rounded),
                        label: const Text('Change Password'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
