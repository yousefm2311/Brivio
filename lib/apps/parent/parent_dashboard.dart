import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client_wrapper.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/academy/presentation/screens/academy_screens.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';

class ParentDashboard extends StatefulWidget {
  final AuthViewModel authViewModel;

  const ParentDashboard({super.key, required this.authViewModel});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  bool _isLoading = false;
  List<Student> _linkedChildren = [];
  Student? _selectedChild;
  List<GroupEntity> _childGroups = [];

  @override
  void initState() {
    super.initState();
    _loadLinkedChildren();
  }

  Future<void> _loadLinkedChildren() async {
    setState(() => _isLoading = true);
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final parentRepo = SupabaseParentRepository(wrapper);

      final parentId = widget.authViewModel.bootstrap?.parentId;
      List<Student> children = [];
      if (parentId != null) {
        children = await parentRepo.fetchLinkedStudents(parentId);
      }

      final selected = children.isNotEmpty ? children.first : null;
      setState(() {
        _linkedChildren = children;
        _selectedChild = selected;
        _isLoading = false;
      });

      if (selected != null) {
        await _loadGroupsForChild(selected);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroupsForChild(Student child) async {
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final enrollmentRepo = SupabaseEnrollmentRepository(wrapper);
      final groupRepo = SupabaseGroupRepository(wrapper);

      final enrollments = await enrollmentRepo.fetchEnrollmentsForStudent(
        child.id,
      );
      final enrolledGroupIds = enrollments.map((e) => e.groupId).toSet();
      List<GroupEntity> groups = [];
      if (enrolledGroupIds.isNotEmpty) {
        final allGroups = await groupRepo.fetchGroups();
        groups = allGroups
            .where((g) => enrolledGroupIds.contains(g.id))
            .toList();
      }
      setState(() {
        _childGroups = groups;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authViewModel.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Guardian Portal'),
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
                  Icons.family_restroom,
                  size: 36,
                  color: Colors.orange,
                ),
                title: Text('Guardian: ${user?.fullName ?? "Parent"}'),
                subtitle: Text('Linked Children (${_linkedChildren.length})'),
              ),
            ),
            const SizedBox(height: 16),
            if (_linkedChildren.isNotEmpty) ...[
              const Text(
                'Select Linked Child:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButton<Student>(
                value: _selectedChild,
                isExpanded: true,
                items: _linkedChildren.map((c) {
                  return DropdownMenuItem<Student>(
                    value: c,
                    child: Text('${c.fullName} (${c.studentCode})'),
                  );
                }).toList(),
                onChanged: (Student? val) {
                  setState(() => _selectedChild = val);
                  if (val != null) {
                    _loadGroupsForChild(val);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
            Text(
              _selectedChild != null
                  ? 'Groups for ${_selectedChild!.fullName}'
                  : 'Child Enrolled Groups',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 350,
              child: GroupListWidget(
                groups: _childGroups,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
