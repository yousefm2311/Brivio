import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/components/buttons.dart';
import '../../../../design_system/components/text_fields.dart';
import '../../../../design_system/components/glass_card.dart';
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

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _qrMessage;
  String? _pendingQrToken;

  Widget? _roleCircle;
  Widget? _purpleCircle;

  late final AnimationController _ambientCtrl;

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
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
        return AppColors.staffRole;
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
      await _consumePendingQrToken();
      widget.onLoginSuccess?.call();
    }
  }

  Future<void> _consumePendingQrToken() async {
    final token = _pendingQrToken;
    if (token == null) return;

    try {
      await Supabase.instance.client.rpc(
        'consume_account_login_qr',
        params: {'p_token': token},
      );
      _pendingQrToken = null;
    } catch (_) {
      // Session established; token cleanup failure can be safely ignored.
    }
  }

  Future<void> _openQrLoginScanner() async {
    final result = await showModalBottomSheet<_QrLoginResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _QrLoginScannerSheet(),
    );
    if (result == null || !mounted) return;

    setState(() {
      _emailController.text = result.email;
      _pendingQrToken = result.token;
      _qrMessage =
          'QR code verified for ${result.fullName}. Enter your account password to sign in.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final state = widget.viewModel.state;

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          body: Stack(
            children: [
              // Animated ambient background
              if (isDark) ...[
                Builder(builder: (context) {
                  _roleCircle ??= Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _roleColor.withValues(alpha: 0.15),
                    ),
                  );
                  _purpleCircle ??= Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.purple.withValues(alpha: 0.12),
                    ),
                  );
                  return const SizedBox();
                }),
                AnimatedBuilder(
                  animation: _ambientCtrl,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        Positioned(
                          top: -150 + math.sin(_ambientCtrl.value * 2 * math.pi) * 50,
                          left: -100 + math.cos(_ambientCtrl.value * 2 * math.pi) * 50,
                          child: _roleCircle!,
                        ),
                        Positioned(
                          bottom: -200 + math.cos(_ambientCtrl.value * 2 * math.pi) * 50,
                          right: -100 + math.sin(_ambientCtrl.value * 2 * math.pi) * 50,
                          child: _purpleCircle!,
                        ),
                      ],
                    );
                  },
                ),
              ],
              // Extreme blur for ambient effect
              if (isDark)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                    child: const SizedBox(),
                  ),
                ),

              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FadeInSlide(
                            duration: const Duration(milliseconds: 600),
                            child: _AppleHeroPanel(
                              roleColor: _roleColor,
                              role: widget.targetRole,
                            ),
                          ),
                          const SizedBox(height: 32),
                          FadeInSlide(
                            duration: const Duration(milliseconds: 600),
                            delay: const Duration(milliseconds: 150),
                            child: GlassCard(
                              padding: const EdgeInsets.all(28),
                              color: isDark ? AppColors.darkSurface.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8),
                              borderColor: isDark ? AppColors.glassBorder : AppColors.lightGlassBorder,
                              blur: 30,
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Sign In',
                                      style: AppTypography.displayMedium(textPrimary).copyWith(letterSpacing: -0.5),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      widget.targetRole == null
                                          ? 'Enter your credentials to access the platform.'
                                          : 'Sign in to your ${widget.targetRole!.displayName.toLowerCase()} workspace.',
                                      style: AppTypography.bodyMedium(textSecondary),
                                    ),
                                    const SizedBox(height: 24),
                                    
                                    if (state.status == AuthStatus.error && state.failure != null) ...[
                                      _AppleAlertBanner(
                                        message: state.failure!.message,
                                        isError: true,
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    if (_qrMessage != null) ...[
                                      _AppleAlertBanner(
                                        message: _qrMessage!,
                                        isError: false,
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    
                                    CustomTextField(
                                      label: 'Email',
                                      hint: 'name@domain.com',
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      prefixIcon: Icons.alternate_email_rounded,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) return 'Please enter your email';
                                        if (!value.contains('@')) return 'Please enter a valid email address';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    CustomTextField(
                                      label: 'Password',
                                      hint: '••••••••',
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      prefixIcon: Icons.lock_outline_rounded,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                          color: textSecondary,
                                          size: 18,
                                        ),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) return 'Please enter your password';
                                        if (value.length < 6) return 'Password must be at least 6 characters';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 28),
                                    PrimaryButton(
                                      text: 'Sign In',
                                      isLoading: state.status == AuthStatus.loading,
                                      onPressed: _handleLogin,
                                      icon: Icons.arrow_forward_rounded,
                                      color: _roleColor,
                                      gradient: LinearGradient(
                                        colors: [
                                          _roleColor,
                                          HSLColor.fromColor(_roleColor).withLightness(math.max(0.0, HSLColor.fromColor(_roleColor).lightness - 0.1)).toColor(),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    
                                    if (widget.targetRole == UserRole.student ||
                                        widget.targetRole == UserRole.parent ||
                                        widget.targetRole == UserRole.teacher ||
                                        widget.targetRole == null) ...[
                                      const SizedBox(height: 16),
                                      GhostButton(
                                        text: 'Sign in with QR Code',
                                        icon: Icons.qr_code_scanner_rounded,
                                        onPressed: state.status == AuthStatus.loading ? null : _openQrLoginScanner,
                                        color: textPrimary,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AppleHeroPanel extends StatelessWidget {
  final Color roleColor;
  final UserRole? role;

  const _AppleHeroPanel({
    required this.roleColor,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlowContainer(
          glowColor: roleColor,
          glowOpacity: 0.25,
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [roleColor, HSLColor.fromColor(roleColor).withLightness(math.max(0.0, HSLColor.fromColor(roleColor).lightness - 0.1)).toColor()],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: 42,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Academy Platform',
          style: AppTypography.hero(Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary).copyWith(fontSize: 32),
          textAlign: TextAlign.center,
        ),
        if (role != null) ...[
          const SizedBox(height: 8),
          StatusChip(
            label: '${role!.displayName} Workspace',
            status: ChipStatus.info,
          ),
        ]
      ],
    );
  }
}

class _AppleAlertBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _AppleAlertBanner({
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isError ? AppColors.error : AppColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: accentColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium(accentColor).copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrLoginResult {
  final String token;
  final String email;
  final String fullName;
  final String role;

  const _QrLoginResult({
    required this.token,
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
          token: token,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: MediaQuery.of(context).size.height * .75,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
            border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 0.5)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Scan QR Code',
                        style: AppTypography.displaySmall(textPrimary),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        MobileScanner(
                          controller: _controller,
                          onDetect: _handleCapture,
                        ),
                        if (_isResolving)
                          Container(
                            color: Colors.black54,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage ?? 'Position the QR code within the frame to sign in.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium(
                    _errorMessage != null ? AppColors.error : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 20), // Bottom safe area spacing
            ],
          ),
        ),
      ),
    );
  }
}
