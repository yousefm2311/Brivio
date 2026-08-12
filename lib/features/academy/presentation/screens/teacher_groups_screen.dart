import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';
import 'teacher_group_details_screen.dart';

class TeacherGroupsScreen extends StatefulWidget {
  final String teacherId;

  const TeacherGroupsScreen({super.key, required this.teacherId});

  @override
  State<TeacherGroupsScreen> createState() => _TeacherGroupsScreenState();
}

class _TeacherGroupsScreenState extends State<TeacherGroupsScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseSubjectRepository _subjectRepo;
  late final SupabaseBranchRepository _branchRepo;
  List<GroupEntity> _groups = [];
  List<SubjectEntity> _subjects = [];
  List<Branch> _branches = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _subjectRepo = SupabaseSubjectRepository(wrapper);
    _branchRepo = SupabaseBranchRepository(wrapper);
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _teacherRepo.fetchAssignedGroups(widget.teacherId),
        _subjectRepo.fetchSubjects(status: 'active'),
        _branchRepo.fetchBranches(status: 'active'),
      ]);
      if (mounted) {
        setState(() {
          _groups = results[0] as List<GroupEntity>;
          _subjects = results[1] as List<SubjectEntity>;
          _branches = results[2] as List<Branch>;
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

  void _openGroupDetails(GroupEntity group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherGroupDetailsScreen(group: group),
      ),
    );
  }

  void _showGroupDialog({GroupEntity? group}) {
    final isEditing = group != null;
    final nameCtrl = TextEditingController(text: group?.name ?? '');
    final codeCtrl = TextEditingController(text: group?.code ?? '');
    final capacityCtrl = TextEditingController(
      text: (group?.maxCapacity ?? 30).toString(),
    );
    String? selectedSubjectId =
        group?.subjectId ?? (_subjects.isNotEmpty ? _subjects.first.id : null);
    String? selectedBranchId =
        group?.branchId ?? (_branches.isNotEmpty ? _branches.first.id : null);
    String status = group?.status ?? 'active';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Group' : 'Create Group'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Group name'),
                  ),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(labelText: 'Group code'),
                  ),
                  if (!isEditing)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedSubjectId,
                      decoration: const InputDecoration(labelText: 'Subject'),
                      items: _subjects
                          .map(
                            (subject) => DropdownMenuItem(
                              value: subject.id,
                              child: Text(subject.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedSubjectId = value),
                    ),
                  if (!isEditing)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedBranchId,
                      decoration: const InputDecoration(labelText: 'Branch'),
                      items: _branches
                          .map(
                            (branch) => DropdownMenuItem(
                              value: branch.id,
                              child: Text(branch.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedBranchId = value),
                    ),
                  TextField(
                    controller: capacityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Capacity'),
                  ),
                  if (isEditing)
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'archived',
                          child: Text('Archived'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => status = value);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: Icon(isEditing ? Icons.save : Icons.add),
              label: Text(isEditing ? 'Save' : 'Create'),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final code = codeCtrl.text.trim();
                final capacity = int.tryParse(capacityCtrl.text.trim()) ?? 30;
                if (name.isEmpty ||
                    code.isEmpty ||
                    (!isEditing &&
                        (selectedSubjectId == null ||
                            selectedBranchId == null))) {
                  return;
                }

                final nav = Navigator.of(ctx);
                try {
                  if (isEditing) {
                    await Supabase.instance.client.rpc(
                      'teacher_update_group',
                      params: {
                        'p_group_id': group.id,
                        'p_name': name,
                        'p_code': code,
                        'p_capacity': capacity,
                        'p_status': status,
                      },
                    );
                  } else {
                    await Supabase.instance.client.rpc(
                      'teacher_create_group',
                      params: {
                        'p_name': name,
                        'p_code': code,
                        'p_subject_id': selectedSubjectId,
                        'p_branch_id': selectedBranchId,
                        'p_capacity': capacity,
                      },
                    );
                  }
                  nav.pop();
                  await _loadGroups();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Group save failed: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _archiveGroup(GroupEntity group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Group'),
        content: Text(
          'Archive ${group.name}? Students and history stay saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client.rpc(
        'teacher_archive_group',
        params: {'p_group_id': group.id},
      );
      await _loadGroups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Archive failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final subtitleColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _subjects.isEmpty || _branches.isEmpty
            ? null
            : () => _showGroupDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Create Group'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Error: $_errorMessage',
                            style: AppTypography.bodyMedium(AppColors.error),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadGroups,
                            child: Text(
                              'Retry',
                              style: AppTypography.labelMedium(textColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : _groups.isEmpty
            ? CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No groups currently assigned to you.',
                        style: AppTypography.bodyMedium(subtitleColor),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _groups.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final g = _groups[i];
                  return FadeInSlide(
                    delay: Duration(milliseconds: 50 * i),
                    child: GlassCard(
                      color: surfaceColor,
                      onTap: () => _openGroupDetails(g),
                      child: Row(
                        children: [
                          const CircleIcon(
                            icon: Icons.group,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.name,
                                  style: AppTypography.titleMedium(textColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Code: ${g.code} | Capacity: ${g.maxCapacity ?? "Unlimited"}',
                                  style: AppTypography.bodySmall(subtitleColor),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _showGroupDialog(group: g);
                              if (value == 'archive') _archiveGroup(g);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit),
                                  title: Text('Edit'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'archive',
                                child: ListTile(
                                  leading: Icon(Icons.archive_outlined),
                                  title: Text('Archive'),
                                ),
                              ),
                            ],
                          ),
                          Icon(Icons.chevron_right, color: subtitleColor),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
