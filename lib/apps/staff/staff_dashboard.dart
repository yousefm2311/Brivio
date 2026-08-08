import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client_wrapper.dart';
import '../../core/security/permission.dart';
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
  List<Student> _students = [];
  List<GroupEntity> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  Future<void> _loadStaffData() async {
    setState(() => _isLoading = true);
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final studentRepo = SupabaseStudentRepository(wrapper);
      final groupRepo = SupabaseGroupRepository(wrapper);

      final studentRes = await studentRepo.fetchStudents();
      final groupRes = await groupRepo.fetchGroups();

      setState(() {
        _students = studentRes.data;
        _groups = groupRes;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
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
        title: const Text('Staff Operations Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => widget.authViewModel.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.badge, size: 36, color: Colors.teal),
                title: Text('Staff Member: ${user?.fullName ?? "Staff"}'),
                subtitle: const Text('Operational Permissions Active'),
              ),
            ),
            const SizedBox(height: 16),
            if (hasStudentsView) ...[
              const Text(
                'Students Directory',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 250,
                child: StudentListWidget(
                  students: _students,
                  isLoading: _isLoading,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (hasGroupsView) ...[
              const Text(
                'Groups Roster',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 250,
                child: GroupListWidget(groups: _groups, isLoading: _isLoading),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
