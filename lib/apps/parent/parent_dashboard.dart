import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client_wrapper.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/widgets/portal_components.dart';
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
  String? _errorMessage;
  List<Student> _linkedChildren = [];
  Student? _selectedChild;
  List<GroupEntity> _childGroups = [];

  @override
  void initState() {
    super.initState();
    _loadLinkedChildren();
  }

  Future<void> _loadLinkedChildren() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final parentRepo = SupabaseParentRepository(wrapper);

      final parentId = widget.authViewModel.bootstrap?.parentId;
      final children = parentId == null
          ? <Student>[]
          : await parentRepo.fetchLinkedStudents(parentId);
      final selected = children.isNotEmpty ? children.first : null;

      if (!mounted) return;
      setState(() {
        _linkedChildren = children;
        _selectedChild = selected;
        _isLoading = false;
      });

      if (selected != null) await _loadGroupsForChild(selected);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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
      final allGroups = enrolledGroupIds.isEmpty
          ? <GroupEntity>[]
          : await groupRepo.fetchGroups();
      final groups = allGroups
          .where((group) => enrolledGroupIds.contains(group.id))
          .toList();

      if (!mounted) return;
      setState(() => _childGroups = groups);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authViewModel.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Portal'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadLinkedChildren,
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: widget.authViewModel.signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLinkedChildren,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PortalHeader(
              eyebrow: 'Guardian Portal',
              title: user?.fullName ?? 'Parent',
              subtitle: '${_linkedChildren.length} linked children',
              icon: Icons.family_restroom,
              accentColor: AppColors.parentRole,
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 16),
            PortalMetricGrid(
              children: [
                PortalMetricCard(
                  label: 'Linked children',
                  value: _linkedChildren.length.toString(),
                  icon: Icons.child_care,
                  accentColor: AppColors.parentRole,
                ),
                PortalMetricCard(
                  label: 'Active groups',
                  value: _childGroups.length.toString(),
                  icon: Icons.group_work,
                  accentColor: AppColors.info,
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              PortalErrorBanner(
                message: _errorMessage!,
                onRetry: _loadLinkedChildren,
              ),
            ],
            const SizedBox(height: 18),
            if (_linkedChildren.isNotEmpty) ...[
              const PortalSectionTitle(title: 'Selected Child'),
              const SizedBox(height: 8),
              DropdownButtonFormField<Student>(
                initialValue: _selectedChild,
                isExpanded: true,
                items: _linkedChildren
                    .map(
                      (child) => DropdownMenuItem<Student>(
                        value: child,
                        child: Text('${child.fullName} (${child.studentCode})'),
                      ),
                    )
                    .toList(),
                onChanged: (child) {
                  if (child == null) return;
                  setState(() => _selectedChild = child);
                  _loadGroupsForChild(child);
                },
              ),
              const SizedBox(height: 18),
            ],
            PortalSectionTitle(
              title: _selectedChild == null
                  ? 'Child Enrolled Groups'
                  : 'Groups for ${_selectedChild!.fullName}',
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
