import 'package:flutter/material.dart';
import 'apps/admin/admin_dashboard.dart';
import 'apps/parent/parent_dashboard.dart';
import 'apps/staff/staff_dashboard.dart';
import 'apps/student/student_dashboard.dart';
import 'apps/teacher/teacher_dashboard.dart';
import 'core/di/injection.dart';
import 'core/security/access_denied_screen.dart';
import 'design_system/theme/app_theme.dart';
import 'features/auth/domain/models/user_role.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/viewmodels/auth_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencyInjection();
  runApp(const MainAppSelector());
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
    return MaterialApp(
      title: 'Academy Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
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
