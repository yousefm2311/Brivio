import 'package:flutter/material.dart';
import '../../core/app/academy_material_app.dart';
import '../../core/di/injection.dart';
import '../../core/security/access_denied_screen.dart';
import '../../features/auth/domain/models/user_role.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'teacher_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencyInjection();
  runApp(const TeacherApp());
}

class TeacherApp extends StatefulWidget {
  const TeacherApp({super.key});

  @override
  State<TeacherApp> createState() => _TeacherAppState();
}

class _TeacherAppState extends State<TeacherApp> {
  late final AuthViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<AuthViewModel>();
    _viewModel.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return AcademyMaterialApp(
      titleKey: 'teacher_portal',
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
            if (role == UserRole.teacher ||
                role == UserRole.admin ||
                role == UserRole.superAdmin) {
              return TeacherDashboard(authViewModel: _viewModel);
            }
            return PortalDeniedScreen(
              currentRole: role,
              targetPortalName: 'Teacher Educator Portal',
              onSignOut: () => _viewModel.signOut(),
            );
          }

          if (state.status == AuthStatus.restricted) {
            return AccountRestrictedScreen(
              onSignOut: () => _viewModel.signOut(),
            );
          }

          return LoginScreen(
            targetRole: UserRole.teacher,
            viewModel: _viewModel,
          );
        },
      ),
    );
  }
}
