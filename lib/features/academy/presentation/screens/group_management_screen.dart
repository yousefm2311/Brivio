import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';

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
                      initialValue: selectedSubjectId,
                      decoration: const InputDecoration(labelText: 'Subject'),
                      items: _subjects
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => selectedSubjectId = v),
                    ),
                  if (_branches.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedBranchId,
                      decoration: const InputDecoration(labelText: 'Branch'),
                      items: _branches
                          .map(
                            (b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(b.name),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGroupDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Group'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Groups',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: $_errorMessage',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : filtered.isEmpty
                ? const Center(child: Text('No groups found.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final g = filtered[i];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.group_work),
                        ),
                        title: Text(
                          g.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Code: ${g.code} | Capacity: ${g.maxCapacity ?? "Unlimited"}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openGroupDetails(g),
                      );
                    },
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTabResources();
  }

  Future<void> _loadTabResources() async {
    setState(() => _isLoading = true);
    try {
      final sRes = await widget.studentRepo.fetchStudents();
      final tRes = await widget.teacherRepo.fetchTeachers();
      if (mounted) {
        setState(() {
          _allStudents = sRes.data;
          _allTeachers = tRes.data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_allStudents.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedStudentId,
                    decoration: const InputDecoration(
                      labelText: 'Select Student',
                    ),
                    items: _allStudents
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.fullName} (${s.studentCode})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setStateDialog(() => selectedStudentId = v),
                  ),
              ],
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_allTeachers.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedTeacherId,
                    decoration: const InputDecoration(
                      labelText: 'Select Teacher',
                    ),
                    items: _allTeachers
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.fullName),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setStateDialog(() => selectedTeacherId = v),
                  ),
                DropdownButtonFormField<String>(
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
      child: Scaffold(
        appBar: AppBar(
          title: Text('Group: ${widget.group.name}'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.info), text: 'Overview'),
              Tab(icon: Icon(Icons.people), text: 'Students'),
              Tab(icon: Icon(Icons.person), text: 'Teachers'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Tab 1: Overview
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Group Name: ${widget.group.name}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Group Code: ${widget.group.code}'),
                            Text(
                              'Max Capacity: ${widget.group.maxCapacity ?? "Unlimited"}',
                            ),
                            Text(
                              'Status: ${widget.group.status.toUpperCase()}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Tab 2: Students
                  Scaffold(
                    floatingActionButton: FloatingActionButton(
                      onPressed: _showEnrollStudentDialog,
                      child: const Icon(Icons.person_add),
                    ),
                    body: _allStudents.isEmpty
                        ? const Center(child: Text('No enrolled students.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _allStudents.length,
                            itemBuilder: (ctx, i) {
                              final s = _allStudents[i];
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.school),
                                  ),
                                  title: Text(s.fullName),
                                  subtitle: Text(
                                    'Code: ${s.studentCode} | Email: ${s.email}',
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  // Tab 3: Teachers
                  Scaffold(
                    floatingActionButton: FloatingActionButton(
                      onPressed: _showAssignTeacherDialog,
                      child: const Icon(Icons.person_add),
                    ),
                    body: _allTeachers.isEmpty
                        ? const Center(child: Text('No assigned teachers.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _allTeachers.length,
                            itemBuilder: (ctx, i) {
                              final t = _allTeachers[i];
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text(t.fullName),
                                  subtitle: Text(
                                    'Email: ${t.email} | Specialization: ${t.specialization ?? "N/A"}',
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
