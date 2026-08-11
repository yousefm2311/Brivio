import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'core/services/notification_service.dart';
import 'core/error/supabase_error_handler.dart';

import 'apps/admin/admin_dashboard.dart';
import 'apps/parent/parent_dashboard.dart';
import 'apps/staff/staff_dashboard.dart';
import 'apps/student/student_dashboard.dart';
import 'apps/teacher/teacher_dashboard.dart';
import 'core/app/academy_material_app.dart';
import 'core/di/injection.dart';
import 'core/logging/app_logger.dart';
import 'core/security/access_denied_screen.dart';
import 'design_system/theme/app_theme.dart';
import 'features/auth/domain/models/user_role.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/viewmodels/auth_viewmodel.dart';

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

final GlobalKey<ScaffoldMessengerState> globalScaffoldMessengerKey = 
    GlobalKey<ScaffoldMessengerState>();

void _showGlobalError(Object error) {
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
    await Firebase.initializeApp();
    await NotificationService().init();
    
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
                return _buildRoleDashboard(role);
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
