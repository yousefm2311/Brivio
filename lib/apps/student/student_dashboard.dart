import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client_wrapper.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/academy/presentation/screens/academy_screens.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';

class StudentDashboard extends StatefulWidget {
  final AuthViewModel authViewModel;

  const StudentDashboard({super.key, required this.authViewModel});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  bool _isLoading = false;
  List<GroupEntity> _enrolledGroups = [];

  @override
  void initState() {
    super.initState();
    _loadEnrolledGroups();
  }

  Future<void> _loadEnrolledGroups() async {
    setState(() => _isLoading = true);
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final enrollmentRepo = SupabaseEnrollmentRepository(wrapper);
      final groupRepo = SupabaseGroupRepository(wrapper);

      final studentId = widget.authViewModel.bootstrap?.studentId;
      List<GroupEntity> groups = [];
      if (studentId != null) {
        final enrollments = await enrollmentRepo.fetchEnrollmentsForStudent(
          studentId,
        );
        final enrolledGroupIds = enrollments.map((e) => e.groupId).toSet();
        if (enrolledGroupIds.isNotEmpty) {
          final allGroups = await groupRepo.fetchGroups();
          groups = allGroups
              .where((g) => enrolledGroupIds.contains(g.id))
              .toList();
        }
      }

      setState(() {
        _enrolledGroups = groups;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authViewModel.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Learning Portal'),
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
                leading: const Icon(
                  Icons.school,
                  size: 36,
                  color: Colors.green,
                ),
                title: Text('Learner: ${user?.fullName ?? "Student"}'),
                subtitle: const Text('My Enrolled Groups & Class Schedules'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'My Active Groups',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 400,
              child: GroupListWidget(
                groups: _enrolledGroups,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
