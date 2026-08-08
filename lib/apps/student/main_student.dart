import 'package:flutter/material.dart';
import '../../core/di/injection.dart';
import '../../core/security/access_denied_screen.dart';
import '../../design_system/theme/app_theme.dart';
import '../../features/auth/domain/models/user_role.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'student_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencyInjection();
  runApp(const StudentApp());
}

class StudentApp extends StatefulWidget {
  const StudentApp({super.key});

  @override
  State<StudentApp> createState() => _StudentAppState();
}

class _StudentAppState extends State<StudentApp> {
  late final AuthViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<AuthViewModel>();
    _viewModel.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Academy - Student Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      home: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final state = _viewModel.state;

          if (state.status == AuthStatus.initial ||
              state.status == AuthStatus.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state.status == AuthStatus.authenticated) {
            final role = _viewModel.userRole;
            if (role == UserRole.student) {
              return StudentDashboard(authViewModel: _viewModel);
            }
            return PortalDeniedScreen(
              currentRole: role,
              targetPortalName: 'Student Learning Portal',
              onSignOut: () => _viewModel.signOut(),
            );
          }

          if (state.status == AuthStatus.restricted) {
            return AccountRestrictedScreen(
              onSignOut: () => _viewModel.signOut(),
            );
          }

          return LoginScreen(
            targetRole: UserRole.student,
            viewModel: _viewModel,
          );
        },
      ),
    );
  }
}
