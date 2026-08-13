import 'package:flutter/material.dart';
import '../../core/app/academy_material_app.dart';
import '../../core/auth/auth_loading_screen.dart';
import '../../core/di/injection.dart';
import '../../design_system/tokens/colors.dart';
import '../../core/security/access_denied_screen.dart';
import '../../features/auth/domain/models/user_role.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'staff_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencyInjection();
  runApp(const StaffApp());
}

class StaffApp extends StatefulWidget {
  const StaffApp({super.key});

  @override
  State<StaffApp> createState() => _StaffAppState();
}

class _StaffAppState extends State<StaffApp> {
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
      titleKey: 'staff_portal',
      home: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final state = _viewModel.state;

          if (state.status == AuthStatus.initial ||
              state.status == AuthStatus.loading) {
            return const AuthLoadingScreen(
              title: 'Opening staff portal',
              subtitle: 'Loading operations, permissions, and secure access.',
              icon: Icons.support_agent_rounded,
              accentColor: AppColors.staffRole,
            );
          }

          if (state.status == AuthStatus.authenticated) {
            final role = _viewModel.userRole;
            if (role == UserRole.staff ||
                role == UserRole.admin ||
                role == UserRole.superAdmin) {
              return StaffDashboard(authViewModel: _viewModel);
            }
            return PortalDeniedScreen(
              currentRole: role,
              targetPortalName: 'Operations Staff Application',
              onSignOut: () => _viewModel.signOut(),
            );
          }

          if (state.status == AuthStatus.restricted) {
            return AccountRestrictedScreen(
              onSignOut: () => _viewModel.signOut(),
            );
          }

          return LoginScreen(targetRole: UserRole.staff, viewModel: _viewModel);
        },
      ),
    );
  }
}
