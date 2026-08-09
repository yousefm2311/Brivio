import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/components/buttons.dart';
import '../../../../design_system/components/text_fields.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../domain/models/user_role.dart';
import '../viewmodels/auth_viewmodel.dart';

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
  String? _qrMessage;

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

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await widget.viewModel.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (widget.viewModel.state.status == AuthStatus.authenticated) {
      widget.onLoginSuccess?.call();
    }
  }

  Future<void> _openQrLoginScanner() async {
    final result = await showModalBottomSheet<_QrLoginResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _QrLoginScannerSheet(),
    );
    if (result == null || !mounted) return;

    setState(() {
      _emailController.text = result.email;
      _qrMessage =
          'QR matched ${result.fullName}. Enter the account password from the invite to continue.';
    });
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 860;
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Flex(
                        direction: isWide ? Axis.horizontal : Axis.vertical,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            flex: isWide ? 5 : 0,
                            fit: isWide ? FlexFit.tight : FlexFit.loose,
                            child: _LoginBrandPanel(
                              roleColor: _roleColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ),
                          SizedBox(
                            width: isWide ? 24 : 0,
                            height: isWide ? 0 : 18,
                          ),
                          Flexible(
                            flex: isWide ? 4 : 0,
                            fit: isWide ? FlexFit.tight : FlexFit.loose,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(22),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _RoleBadge(
                                        role: widget.targetRole,
                                        color: _roleColor,
                                      ),
                                      const SizedBox(height: 22),
                                      Text(
                                        'Welcome Back',
                                        style: AppTypography.displayMedium(
                                          textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        widget.targetRole == null
                                            ? 'Sign in to access your academy workspace.'
                                            : 'Sign in to access your ${widget.targetRole!.displayName.toLowerCase()} workspace.',
                                        style: AppTypography.bodyLarge(
                                          textSecondary,
                                        ),
                                      ),
                                      if (state.status == AuthStatus.error &&
                                          state.failure != null) ...[
                                        const SizedBox(height: 18),
                                        _ErrorBanner(
                                          message: state.failure!.message,
                                        ),
                                      ],
                                      if (_qrMessage != null) ...[
                                        const SizedBox(height: 18),
                                        _InfoBanner(message: _qrMessage!),
                                      ],
                                      const SizedBox(height: 22),
                                      CustomTextField(
                                        label: 'Email Address',
                                        hint: 'name@academy.com',
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        prefixIcon: Icons.email_outlined,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter your email';
                                          }
                                          if (!value.contains('@')) {
                                            return 'Please enter a valid email address';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 18),
                                      CustomTextField(
                                        label: 'Password',
                                        hint: 'Password',
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
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter your password';
                                          }
                                          if (value.length < 6) {
                                            return 'Password must be at least 6 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 26),
                                      PrimaryButton(
                                        text: 'Sign In',
                                        isLoading:
                                            state.status == AuthStatus.loading,
                                        onPressed: _handleLogin,
                                        icon: Icons.login_rounded,
                                      ),
                                      if (widget.targetRole ==
                                              UserRole.student ||
                                          widget.targetRole ==
                                              UserRole.parent ||
                                          widget.targetRole ==
                                              UserRole.teacher ||
                                          widget.targetRole == null) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed:
                                                state.status ==
                                                    AuthStatus.loading
                                                ? null
                                                : _openQrLoginScanner,
                                            icon: const Icon(
                                              Icons.qr_code_scanner,
                                            ),
                                            label: const Text(
                                              'Sign in using QR Code',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _LoginBrandPanel extends StatelessWidget {
  final Color roleColor;
  final Color textPrimary;
  final Color textSecondary;

  const _LoginBrandPanel({
    required this.roleColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: roleColor.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: roleColor.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: roleColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.code, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 22),
          Text(
            'CodeStart Academy',
            style: AppTypography.displayLarge(textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            'A focused workspace for programming lessons, progress tracking, attendance, content, and operations.',
            style: AppTypography.bodyLarge(textSecondary),
          ),
          const SizedBox(height: 22),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _BrandPill(icon: Icons.school, label: 'Students'),
              _BrandPill(icon: Icons.person, label: 'Teachers'),
              _BrandPill(icon: Icons.family_restroom, label: 'Parents'),
              _BrandPill(icon: Icons.admin_panel_settings, label: 'Admin'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final UserRole? role;
  final Color color;

  const _RoleBadge({required this.role, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            role == null
                ? 'Academy Platform Portal'
                : '${role!.displayName} Portal',
            style: AppTypography.caption(
              color,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _BrandPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BrandPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _QrLoginResult {
  final String email;
  final String fullName;
  final String role;

  const _QrLoginResult({
    required this.email,
    required this.fullName,
    required this.role,
  });
}

class _QrLoginScannerSheet extends StatefulWidget {
  const _QrLoginScannerSheet();

  @override
  State<_QrLoginScannerSheet> createState() => _QrLoginScannerSheetState();
}

class _QrLoginScannerSheetState extends State<_QrLoginScannerSheet> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isResolving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_isResolving) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .where((raw) => raw.trim().isNotEmpty)
        .firstOrNull;
    if (value == null) return;

    final token = _extractAccountQrToken(value);
    if (token == null) {
      setState(() => _errorMessage = 'This is not an account login QR.');
      return;
    }

    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'resolve_account_login_qr',
        params: {'p_token': token},
      );
      final json = Map<String, dynamic>.from(response as Map);
      if (!mounted) return;
      Navigator.pop(
        context,
        _QrLoginResult(
          email: json['email']?.toString() ?? '',
          fullName: json['full_name']?.toString() ?? 'Account',
          role: json['role']?.toString() ?? '',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isResolving = false;
      });
    }
  }

  String? _extractAccountQrToken(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['type'] == 'account_login_qr') {
        return decoded['token']?.toString();
      }
    } catch (_) {}

    if (raw.startsWith('acctqr_')) return raw;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .74,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Scan Account Login QR',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _handleCapture,
                  ),
                  if (_isResolving)
                    const ColoredBox(
                      color: Colors.black45,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Scan the QR generated by Admin or Staff. The QR contains a temporary token, not a password.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;

  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2, color: AppColors.info, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium(AppColors.info),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium(AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
