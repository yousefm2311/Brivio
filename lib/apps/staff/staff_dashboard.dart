import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client_wrapper.dart';
import '../../core/security/permission.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/widgets/portal_components.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/academy/presentation/screens/academy_screens.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';

class StaffDashboard extends StatefulWidget {
  final AuthViewModel authViewModel;

  const StaffDashboard({super.key, required this.authViewModel});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Student> _students = [];
  List<GroupEntity> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  Future<void> _loadStaffData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final studentRepo = SupabaseStudentRepository(wrapper);
      final groupRepo = SupabaseGroupRepository(wrapper);

      final studentRes = await studentRepo.fetchStudents();
      final groupRes = await groupRepo.fetchGroups();

      if (!mounted) return;
      setState(() {
        _students = studentRes.data;
        _groups = groupRes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authViewModel.currentUser;
    final hasStudentsView = widget.authViewModel.state.hasPermission(
      Permission.studentsView,
    );
    final hasGroupsView = widget.authViewModel.state.hasPermission(
      Permission.groupsView,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Portal'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadStaffData,
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: widget.authViewModel.signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStaffData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PortalHeader(
              eyebrow: 'Operations Portal',
              title: user?.fullName ?? 'Staff Member',
              subtitle: 'Operational permissions active',
              icon: Icons.badge,
              accentColor: AppColors.accent,
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 16),
            PortalMetricGrid(
              children: [
                PortalMetricCard(
                  label: 'Students visible',
                  value: hasStudentsView ? _students.length.toString() : 'No',
                  icon: Icons.school,
                  accentColor: AppColors.info,
                ),
                PortalMetricCard(
                  label: 'Groups visible',
                  value: hasGroupsView ? _groups.length.toString() : 'No',
                  icon: Icons.group_work,
                  accentColor: AppColors.accent,
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              PortalErrorBanner(
                message: _errorMessage!,
                onRetry: _loadStaffData,
              ),
            ],
            if (hasStudentsView) ...[
              const SizedBox(height: 18),
              const PortalSectionTitle(title: 'Students Directory'),
              const SizedBox(height: 8),
              SizedBox(
                height: 260,
                child: StudentListWidget(
                  students: _students,
                  isLoading: _isLoading,
                ),
              ),
            ],
            if (hasGroupsView) ...[
              const SizedBox(height: 18),
              const PortalSectionTitle(title: 'Groups Roster'),
              const SizedBox(height: 8),
              SizedBox(
                height: 260,
                child: GroupListWidget(groups: _groups, isLoading: _isLoading),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
