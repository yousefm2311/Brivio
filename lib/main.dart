import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'core/config/app_config.dart';
import 'core/error/supabase_error_handler.dart';
import 'firebase_options.dart';
import 'apps/admin/admin_dashboard.dart';
import 'apps/parent/parent_dashboard.dart';
import 'apps/staff/staff_dashboard.dart';
import 'apps/student/student_dashboard.dart';
import 'apps/teacher/teacher_dashboard.dart';
import 'core/app/academy_material_app.dart';
import 'core/auth/auth_loading_screen.dart';
import 'core/di/injection.dart';
import 'core/logging/app_logger.dart';
import 'core/security/access_denied_screen.dart';
import 'core/services/settings_service.dart';
import 'design_system/tokens/colors.dart';
import 'design_system/theme/app_theme.dart';
import 'features/auth/domain/models/user_role.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/viewmodels/auth_viewmodel.dart';

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

final GlobalKey<ScaffoldMessengerState> globalScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void _showGlobalError(Object error) {
  if (!_shouldShowGlobalError(error)) return;
  final message = SupabaseErrorHandler.parseError(error);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (globalScaffoldMessengerKey.currentState != null) {
      globalScaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  });
}

bool _shouldShowGlobalError(Object error) {
  final text = error.toString();
  return !text.contains(
    'ListTile background color or ink splashes may be invisible',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _showGlobalError(details.exception);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Unhandled async error', error, stack);
    _showGlobalError(error);
    return true;
  };

  try {
    await _initializeFirebaseIfAvailable();

    final appDir = await getApplicationDocumentsDirectory();
    Hive.init(appDir.path);
    await Hive.openBox('study_workspace_cache');

    await setupDependencyInjection().timeout(const Duration(seconds: 20));
    runApp(const MainAppSelector());
  } catch (error, stackTrace) {
    AppLogger.error('Application startup failed', error, stackTrace);
    runApp(StartupFailureApp(error: error));
  }
}

bool get _supportsFirebaseRuntime {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

Future<void> _initializeFirebaseIfAvailable() async {
  if (!_supportsFirebaseRuntime || Firebase.apps.isNotEmpty) return;
  try {
    if (AppConfig.hasFirebaseConfig) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (error, stackTrace) {
    AppLogger.warning('Firebase is not configured for this runtime.');
    AppLogger.error('Firebase startup skipped', error, stackTrace);
  }
}

class StartupFailureApp extends StatelessWidget {
  final Object error;

  const StartupFailureApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: globalScaffoldMessengerKey,
      title: 'Academy Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Startup failed',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      main();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainAppSelector extends StatefulWidget {
  const MainAppSelector({super.key});

  @override
  State<MainAppSelector> createState() => _MainAppSelectorState();
}

class _MainAppSelectorState extends State<MainAppSelector> {
  late final AuthViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<AuthViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.restoreSession();
    });
  }

  Widget _buildRoleDashboard(UserRole role) {
    switch (role) {
      case UserRole.admin:
      case UserRole.superAdmin:
        return AdminDashboard(authViewModel: _viewModel);
      case UserRole.staff:
        return StaffDashboard(authViewModel: _viewModel);
      case UserRole.teacher:
        return TeacherDashboard(authViewModel: _viewModel);
      case UserRole.student:
        return StudentDashboard(authViewModel: _viewModel);
      case UserRole.parent:
        return ParentDashboard(authViewModel: _viewModel);
      case UserRole.unknown:
        return PortalDeniedScreen(
          currentRole: role,
          targetPortalName: 'Academy Platform',
          onSignOut: () => _viewModel.signOut(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AcademyMaterialApp(
      navigatorKey: globalNavigatorKey,
      scaffoldMessengerKey: globalScaffoldMessengerKey,
      titleKey: 'academy_platform',
      home: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final state = _viewModel.state;

          switch (state.status) {
            case AuthStatus.initial:
            case AuthStatus.loading:
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            case AuthStatus.authenticated:
              final role = _viewModel.userRole;
              if (role != null) {
                return BiometricGate(
                  onSignOut: () => _viewModel.signOut(),
                  child: _buildRoleDashboard(role),
                );
              }
              return PortalDeniedScreen(
                currentRole: role,
                targetPortalName: 'Academy Platform',
                onSignOut: () => _viewModel.signOut(),
              );
            case AuthStatus.restricted:
              return AccountRestrictedScreen(
                onSignOut: () => _viewModel.signOut(),
              );
            case AuthStatus.unauthenticated:
            case AuthStatus.error:
              return LoginScreen(viewModel: _viewModel);
          }
        },
      ),
    );
  }
}

class BiometricGate extends StatefulWidget {
  final Widget child;
  final VoidCallback onSignOut;

  const BiometricGate({
    super.key,
    required this.child,
    required this.onSignOut,
  });

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  bool _unlocked = false;
  bool _checking = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final settings = getIt<SettingsService>();
    if (!settings.biometricLogin || kIsWeb) {
      if (mounted) {
        setState(() {
          _unlocked = true;
          _checking = false;
        });
      }
      return;
    }

    try {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      final canCheckBiometrics = await auth.canCheckBiometrics;
      if (!supported && !canCheckBiometrics) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Biometric login is enabled, but this device has no available secure unlock method.';
          _checking = false;
        });
        return;
      }

      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Unlock your academy portal',
      );
      if (!mounted) return;
      setState(() {
        _unlocked = didAuthenticate;
        _checking = false;
        _errorMessage = didAuthenticate ? null : 'Authentication was canceled.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _errorMessage =
            'Secure unlock is temporarily unavailable. You can try again or sign out.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;

    if (_checking) {
      return const AuthLoadingScreen(
        title: 'Secure unlock',
        subtitle: 'Checking your fingerprint and preparing the academy portal.',
        icon: Icons.fingerprint_rounded,
        accentColor: AppColors.primary,
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.fingerprint_rounded,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Biometric unlock',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Unlock was not completed.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _checking = true;
                              _errorMessage = null;
                            });
                            _unlock();
                          },
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Try again'),
                        ),
                        TextButton(
                          onPressed: widget.onSignOut,
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
