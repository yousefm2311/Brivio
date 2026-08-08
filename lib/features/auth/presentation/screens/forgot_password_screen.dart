import 'package:flutter/material.dart';
import '../../../../design_system/components/buttons.dart';
import '../../../../design_system/components/text_fields.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../viewmodels/auth_viewmodel.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final AuthViewModel viewModel;

  const ForgotPasswordScreen({super.key, required this.viewModel});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleReset() async {
    if (_formKey.currentState?.validate() ?? false) {
      await widget.viewModel.sendPasswordReset(_emailController.text);
      if (widget.viewModel.state.status != AuthStatus.error) {
        setState(() {
          _emailSent = true;
        });
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
          appBar: AppBar(title: const Text('Reset Password')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Forgot Password?',
                          style: AppTypography.displayMedium(textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your account email address and we will send password reset recovery instructions.',
                          style: AppTypography.bodyLarge(textSecondary),
                        ),
                        const SizedBox(height: 32),

                        if (_emailSent) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Password reset recovery email sent. Please check your inbox.',
                                    style: AppTypography.bodyMedium(
                                      AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

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
                            child: Text(
                              state.failure!.message,
                              style: AppTypography.bodyMedium(AppColors.error),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

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
                        const SizedBox(height: 32),

                        PrimaryButton(
                          text: 'Send Recovery Email',
                          isLoading: state.status == AuthStatus.loading,
                          onPressed: _handleReset,
                          icon: Icons.mark_email_read_rounded,
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
