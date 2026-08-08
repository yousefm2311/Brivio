import 'package:flutter/material.dart';
import '../../../../design_system/components/buttons.dart';
import '../../../../design_system/components/text_fields.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../domain/models/user_role.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Reusable Login screen supporting all target apps with role badge styling.
class LoginScreen extends StatefulWidget {
  final UserRole? targetRole;
  final AuthViewModel viewModel;
  final VoidCallback? onLoginSuccess;

  const LoginScreen({
    super.key,
    this.targetRole,
    required this.viewModel,
    this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Color get _roleColor {
    if (widget.targetRole == null) return AppColors.primary;
    switch (widget.targetRole!) {
      case UserRole.student:
        return AppColors.studentRole;
      case UserRole.teacher:
        return AppColors.teacherRole;
      case UserRole.parent:
        return AppColors.parentRole;
      case UserRole.staff:
        return AppColors.accent;
      case UserRole.admin:
      case UserRole.superAdmin:
        return AppColors.adminRole;
      case UserRole.unknown:
        return AppColors.primary;
    }
  }

  void _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      await widget.viewModel.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (widget.viewModel.state.status == AuthStatus.authenticated) {
        widget.onLoginSuccess?.call();
      }
    }
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

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _roleColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _roleColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 16,
                                color: _roleColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.targetRole != null
                                    ? '${widget.targetRole!.displayName} Portal'
                                    : 'Academy Platform Portal',
                                style: AppTypography.caption(
                                  _roleColor,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title & Subtitle
                        Text(
                          'Welcome Back',
                          style: AppTypography.displayLarge(textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.targetRole != null
                              ? 'Sign in to access your ${widget.targetRole!.displayName.toLowerCase()} workspace.'
                              : 'Sign in to access your academy workspace.',
                          style: AppTypography.bodyLarge(textSecondary),
                        ),
                        const SizedBox(height: 32),

                        // Error Banner
                        if (state.status == AuthStatus.error &&
                            state.failure != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    state.failure!.message,
                                    style: AppTypography.bodyMedium(
                                      AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Inputs
                        CustomTextField(
                          label: 'Email Address',
                          hint: 'name@academy.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        CustomTextField(
                          label: 'Password',
                          hint: '••••••••',
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: textSecondary,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        PrimaryButton(
                          text: 'Sign In',
                          isLoading: state.status == AuthStatus.loading,
                          onPressed: _handleLogin,
                          icon: Icons.login_rounded,
                        ),
                      ],
                    ),
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
