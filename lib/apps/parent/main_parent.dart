import 'package:flutter/material.dart';
import '../../core/di/injection.dart';
import '../../core/security/access_denied_screen.dart';
import '../../design_system/theme/app_theme.dart';
import '../../features/auth/domain/models/user_role.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'parent_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencyInjection();
  runApp(const ParentApp());
}

class ParentApp extends StatefulWidget {
  const ParentApp({super.key});

  @override
  State<ParentApp> createState() => _ParentAppState();
}

class _ParentAppState extends State<ParentApp> {
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
      title: 'Academy - Parent Portal',
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
            if (role == UserRole.parent) {
              return ParentDashboard(authViewModel: _viewModel);
            }
            return PortalDeniedScreen(
              currentRole: role,
              targetPortalName: 'Parent Guardian Application',
              onSignOut: () => _viewModel.signOut(),
            );
          }

          if (state.status == AuthStatus.restricted) {
            return AccountRestrictedScreen(
              onSignOut: () => _viewModel.signOut(),
            );
          }

          return LoginScreen(
            targetRole: UserRole.parent,
            viewModel: _viewModel,
          );
        },
      ),
    );
  }
}
