import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';

Widget _dropdownText(String value) {
  return Text(value, maxLines: 1, overflow: TextOverflow.ellipsis);
}

class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  late final SupabaseGroupRepository _groupRepo;
  late final SupabaseSubjectRepository _subjectRepo;
  late final SupabaseBranchRepository _branchRepo;
  late final SupabaseStudentRepository _studentRepo;
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseEnrollmentRepository _enrollmentRepo;

  List<GroupEntity> _groups = [];
  List<SubjectEntity> _subjects = [];
  List<Branch> _branches = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _groupRepo = SupabaseGroupRepository(wrapper);
    _subjectRepo = SupabaseSubjectRepository(wrapper);
    _branchRepo = SupabaseBranchRepository(wrapper);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _enrollmentRepo = SupabaseEnrollmentRepository(wrapper);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final g = await _groupRepo.fetchGroups();
      final s = await _subjectRepo.fetchSubjects();
      final b = await _branchRepo.fetchBranches();
      if (mounted) {
        setState(() {
          _groups = g;
          _subjects = s;
          _branches = b;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showCreateGroupDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '20');
    String? selectedSubjectId = _subjects.isNotEmpty
        ? _subjects.first.id
        : null;
    String? selectedBranchId = _branches.isNotEmpty ? _branches.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Create New Group'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Group Name (e.g. Programming Level 1)',
                    ),
                  ),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Group Code (e.g. GRP-PROG1)',
                    ),
                  ),
                  if (_subjects.isNotEmpty)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedSubjectId,
                      decoration: const InputDecoration(labelText: 'Subject'),
                      items: _subjects
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: _dropdownText(s.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => selectedSubjectId = v),
                    ),
                  if (_branches.isNotEmpty)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedBranchId,
                      decoration: const InputDecoration(labelText: 'Branch'),
                      items: _branches
                          .map(
                            (b) => DropdownMenuItem(
                              value: b.id,
                              child: _dropdownText(b.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => selectedBranchId = v),
                    ),
                  TextField(
                    controller: capacityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Max Capacity',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty ||
                      codeCtrl.text.trim().isEmpty ||
                      selectedSubjectId == null ||
                      selectedBranchId == null) {
                    return;
                  }

                  final nav = Navigator.of(ctx);
                  try {
                    final g = GroupEntity(
                      id: '',
                      code: codeCtrl.text.trim(),
                      name: nameCtrl.text.trim(),
                      subjectId: selectedSubjectId!,
                      branchId: selectedBranchId!,
                      maxCapacity: int.tryParse(capacityCtrl.text) ?? 20,
                      status: 'active',
                    );

                    await _groupRepo.createGroup(g);
                    nav.pop();
                    _loadData();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to create group: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Create Group'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openGroupDetails(GroupEntity g) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailsScreen(
          group: g,
          studentRepo: _studentRepo,
          teacherRepo: _teacherRepo,
          enrollmentRepo: _enrollmentRepo,
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _groups.where((g) {
      final q = _searchController.text.toLowerCase();
      return g.name.toLowerCase().contains(q) ||
          g.code.toLowerCase().contains(q);
    }).toList();

    return PortalPageShell(
      title: 'Group Management',
      subtitle: 'Create groups, open rosters, and manage capacity.',
      icon: Icons.group_work,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'Refresh',
          onPressed: _loadData,
        ),
        PortalAction(
          icon: Icons.add,
          label: 'Add Group',
          onPressed: _showCreateGroupDialog,
          primary: true,
        ),
      ],
      child: Column(
        children: [
          PortalSearchField(
            controller: _searchController,
            label: 'Search groups',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: 'No groups found',
              emptySubtitle: 'Create a subject and branch, then add a group.',
              emptyIcon: Icons.group_work,
              onRetry: _loadData,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final g = filtered[i];
                  return PortalListCard(
                    icon: Icons.group_work,
                    accentColor: AppColors.adminRole,
                    title: g.name,
                    subtitle:
                        'Code: ${g.code} | Capacity: ${g.maxCapacity ?? "Unlimited"}',
                    trailing: [
                      PortalStatusChip(status: g.status),
                      const Icon(Icons.chevron_right),
                    ],
                    onTap: () => _openGroupDetails(g),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GroupDetailsScreen extends StatefulWidget {
  final GroupEntity group;
  final SupabaseStudentRepository studentRepo;
  final SupabaseTeacherRepository teacherRepo;
  final SupabaseEnrollmentRepository enrollmentRepo;

  const GroupDetailsScreen({
    super.key,
    required this.group,
    required this.studentRepo,
    required this.teacherRepo,
    required this.enrollmentRepo,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  List<Student> _allStudents = [];
  List<Teacher> _allTeachers = [];
  List<Student> _enrolledStudents = [];
  List<Teacher> _assignedTeachers = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTabResources();
  }

  Future<void> _loadTabResources() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final sRes = await widget.studentRepo.fetchStudents();
      final tRes = await widget.teacherRepo.fetchTeachers();
      final enrolled = await widget.studentRepo.fetchStudentsForGroup(
        widget.group.id,
      );
      final assignments = await Supabase.instance.client
          .from('group_teachers')
          .select('teacher_id')
          .eq('group_id', widget.group.id);
      final assignedIds = (assignments as List<dynamic>)
          .map((item) => (item as Map)['teacher_id'] as String)
          .toSet();
      if (mounted) {
        setState(() {
          _allStudents = sRes.data;
          _allTeachers = tRes.data;
          _enrolledStudents = enrolled;
          _assignedTeachers = _allTeachers
              .where((teacher) => assignedIds.contains(teacher.id))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _showEnrollStudentDialog() {
    String? selectedStudentId = _allStudents.isNotEmpty
        ? _allStudents.first.id
        : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Enroll Student in Group'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_allStudents.isNotEmpty)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedStudentId,
                      decoration: const InputDecoration(
                        labelText: 'Select Student',
                      ),
                      items: _allStudents
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: _dropdownText(
                                '${s.fullName} (${s.studentCode})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => selectedStudentId = v),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedStudentId == null) return;
                  final nav = Navigator.of(ctx);
                  try {
                    await widget.enrollmentRepo.enrollStudentInGroup(
                      studentId: selectedStudentId!,
                      groupId: widget.group.id,
                    );
                    nav.pop();
                    _loadTabResources();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Student enrolled successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Enrollment failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Enroll'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAssignTeacherDialog() {
    String? selectedTeacherId = _allTeachers.isNotEmpty
        ? _allTeachers.first.id
        : null;
    String role = 'primary';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Assign Teacher to Group'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_allTeachers.isNotEmpty)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedTeacherId,
                      decoration: const InputDecoration(
                        labelText: 'Select Teacher',
                      ),
                      items: _allTeachers
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.id,
                              child: _dropdownText(t.fullName),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => selectedTeacherId = v),
                    ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(
                        value: 'primary',
                        child: Text('Primary Teacher'),
                      ),
                      DropdownMenuItem(
                        value: 'co_teacher',
                        child: Text('Co-Teacher'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => role = v);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedTeacherId == null) return;
                  final nav = Navigator.of(ctx);
                  try {
                    await Supabase.instance.client.rpc(
                      'assign_teacher_to_group',
                      params: {
                        'p_teacher_id': selectedTeacherId,
                        'p_group_id': widget.group.id,
                        'p_role': role,
                      },
                    );
                    nav.pop();
                    _loadTabResources();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Teacher assigned successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Teacher assignment failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Assign Teacher'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: PortalPageShell(
        title: widget.group.name,
        subtitle:
            'Code: ${widget.group.code} | Capacity: ${widget.group.maxCapacity ?? "Unlimited"}',
        icon: Icons.group_work,
        accentColor: AppColors.adminRole,
        actions: [
          PortalAction(
            icon: Icons.arrow_back,
            label: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          PortalAction(
            icon: Icons.refresh,
            label: 'Refresh',
            onPressed: _loadTabResources,
          ),
        ],
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.info), text: 'Overview'),
                Tab(icon: Icon(Icons.people), text: 'Students'),
                Tab(icon: Icon(Icons.person), text: 'Teachers'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PortalStateView(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: false,
                emptyTitle: 'No group data',
                emptySubtitle: 'Refresh group resources and try again.',
                emptyIcon: Icons.group_work,
                onRetry: _loadTabResources,
                child: TabBarView(
                  children: [
                    ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        PortalMetricGrid(
                          children: [
                            PortalMetricCard(
                              label: 'Enrolled Students',
                              value: _enrolledStudents.length.toString(),
                              icon: Icons.school,
                              accentColor: AppColors.studentRole,
                            ),
                            PortalMetricCard(
                              label: 'Assigned Teachers',
                              value: _assignedTeachers.length.toString(),
                              icon: Icons.person,
                              accentColor: AppColors.teacherRole,
                            ),
                            PortalMetricCard(
                              label: 'Capacity',
                              value:
                                  widget.group.maxCapacity?.toString() ?? '-',
                              icon: Icons.event_seat,
                              accentColor: AppColors.info,
                            ),
                            PortalMetricCard(
                              label: 'Status',
                              value: widget.group.status.toUpperCase(),
                              icon: Icons.verified,
                              accentColor: AppColors.success,
                            ),
                          ],
                        ),
                      ],
                    ),
                    Stack(
                      children: [
                        _enrolledStudents.isEmpty
                            ? const Center(child: Text('No enrolled students.'))
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 72),
                                itemCount: _enrolledStudents.length,
                                separatorBuilder: (ctx, i) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final s = _enrolledStudents[i];
                                  return PortalListCard(
                                    icon: Icons.school,
                                    accentColor: AppColors.studentRole,
                                    title: s.fullName,
                                    subtitle:
                                        'Code: ${s.studentCode} | Email: ${s.email}',
                                    trailing: [
                                      PortalStatusChip(status: s.status),
                                    ],
                                  );
                                },
                              ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: FilledButton.icon(
                            onPressed: _showEnrollStudentDialog,
                            icon: const Icon(Icons.person_add),
                            label: const Text('Enroll'),
                          ),
                        ),
                      ],
                    ),
                    Stack(
                      children: [
                        _assignedTeachers.isEmpty
                            ? const Center(child: Text('No assigned teachers.'))
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 72),
                                itemCount: _assignedTeachers.length,
                                separatorBuilder: (ctx, i) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final t = _assignedTeachers[i];
                                  return PortalListCard(
                                    icon: Icons.person,
                                    accentColor: AppColors.teacherRole,
                                    title: t.fullName,
                                    subtitle:
                                        'Email: ${t.email} | Specialization: ${t.specialization ?? "N/A"}',
                                  );
                                },
                              ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: FilledButton.icon(
                            onPressed: _showAssignTeacherDialog,
                            icon: const Icon(Icons.person_add),
                            label: const Text('Assign'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
