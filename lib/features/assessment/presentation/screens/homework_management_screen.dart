import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';

class HomeworkManagementScreen extends StatefulWidget {
  const HomeworkManagementScreen({super.key});

  @override
  State<HomeworkManagementScreen> createState() =>
      _HomeworkManagementScreenState();
}

class _HomeworkManagementScreenState extends State<HomeworkManagementScreen> {
  late final SupabaseHomeworkRepository _homeworkRepo;
  late final SupabaseGroupRepository _groupRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Homework> _homeworks = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _homeworkRepo = SupabaseHomeworkRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _groupRepo = SupabaseGroupRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _loadHomeworks();
  }

  Future<void> _loadHomeworks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _groupRepo.fetchGroups(status: 'active');
      final selected = _selectedGroup ?? (groups.isEmpty ? null : groups.first);
      final h = selected == null
          ? <Homework>[]
          : await _homeworkRepo.fetchHomeworkForGroup(selected.id);
      if (mounted) {
        setState(() {
          _groups = groups;
          _selectedGroup = selected;
          _homeworks = h;
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

  void _showCreateHomeworkDialog() {
    final selectedGroup = _selectedGroup;
    if (selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create an active group first.')),
      );
      return;
    }
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ptsCtrl = TextEditingController();
    DateTime? dueAt;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Create Homework Assignment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Homework Title',
                  ),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Instructions / Description',
                  ),
                  maxLines: 2,
                ),
                TextField(
                  controller: ptsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Max Score / Points',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDate:
                          dueAt ?? DateTime.now().add(const Duration(days: 7)),
                    );
                    if (picked != null) setStateDialog(() => dueAt = picked);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    dueAt == null
                        ? 'Select due date'
                        : 'Due ${dueAt!.year}-${dueAt!.month}-${dueAt!.day}',
                  ),
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
                final maxScore = double.tryParse(ptsCtrl.text);
                if (titleCtrl.text.trim().isEmpty ||
                    maxScore == null ||
                    maxScore <= 0 ||
                    dueAt == null) {
                  return;
                }

                final nav = Navigator.of(ctx);
                try {
                  final hw = Homework(
                    id: '',
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                    subjectId: selectedGroup.subjectId,
                    groupId: selectedGroup.id,
                    dueAt: dueAt!,
                    maxScore: maxScore,
                    status: 'published',
                  );

                  await _homeworkRepo.createHomework(hw);
                  nav.pop();
                  _loadHomeworks();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Homework assignment published!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Creation failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Publish Homework'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHomeworkDialog(Homework h) {
    final titleCtrl = TextEditingController(text: h.title);
    final descCtrl = TextEditingController(text: h.description ?? '');
    final ptsCtrl = TextEditingController(text: h.maxScore.toString());
    DateTime? dueAt = h.dueAt;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Edit Homework Assignment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Homework Title',
                  ),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Instructions / Description',
                  ),
                  maxLines: 2,
                ),
                TextField(
                  controller: ptsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Max Score / Points',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDate:
                          dueAt ?? DateTime.now().add(const Duration(days: 7)),
                    );
                    if (picked != null) setStateDialog(() => dueAt = picked);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    dueAt == null
                        ? 'Select due date'
                        : 'Due ${dueAt!.year}-${dueAt!.month}-${dueAt!.day}',
                  ),
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
                final maxScore = double.tryParse(ptsCtrl.text);
                if (titleCtrl.text.trim().isEmpty ||
                    maxScore == null ||
                    maxScore <= 0 ||
                    dueAt == null) {
                  return;
                }

                final nav = Navigator.of(ctx);
                try {
                  await Supabase.instance.client
                      .from('homework')
                      .update({
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        'max_score': maxScore,
                        'due_at': dueAt!.toIso8601String(),
                      })
                      .eq('id', h.id);

                  nav.pop();
                  _loadHomeworks();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Homework updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Update failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'Homework Management',
      subtitle: 'Publish group assignments with due dates and scoring.',
      icon: Icons.assignment,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'Refresh',
          onPressed: _loadHomeworks,
        ),
        if (_selectedGroup != null)
          PortalAction(
            icon: Icons.assignment,
            label: 'Add Homework',
            onPressed: _showCreateHomeworkDialog,
            primary: true,
          ),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: false,
        emptyTitle: 'No homework data',
        emptySubtitle: 'Create an active group first.',
        emptyIcon: Icons.assignment,
        onRetry: _loadHomeworks,
        child: Column(
          children: [
            if (_groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<GroupEntity>(
                  initialValue: _selectedGroup,
                  decoration: const InputDecoration(labelText: 'Group'),
                  items: _groups
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text('${g.name} (${g.code})'),
                        ),
                      )
                      .toList(),
                  onChanged: (group) {
                    if (group == null) return;
                    setState(() => _selectedGroup = group);
                    _loadHomeworks();
                  },
                ),
              ),
            Expanded(
              child: _selectedGroup == null
                  ? const Center(child: Text('No active groups found.'))
                  : _homeworks.isEmpty
                  ? const Center(child: Text('No homework assignments found.'))
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _homeworks.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final h = _homeworks[i];
                        return PortalListCard(
                          icon: Icons.assignment,
                          accentColor: AppColors.adminRole,
                          title: h.title,
                          subtitle:
                              'Max Score: ${h.maxScore} | Due: ${h.dueAt.year}-${h.dueAt.month}-${h.dueAt.day} | Status: ${h.status.toUpperCase()}',
                          trailing: [
                            PortalStatusChip(status: h.status),
                            PopupMenuButton<String>(
                              tooltip: 'Actions',
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (value) async {
                                switch (value) {
                                  case 'edit':
                                    _showEditHomeworkDialog(h);
                                    break;
                                  case 'close':
                                    if (h.status == 'closed') return;
                                    try {
                                      await _homeworkRepo.closeHomework(h.id);
                                      _loadHomeworks();
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to close: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                    break;
                                  case 'delete':
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Homework'),
                                        content: const Text(
                                          'Are you sure you want to delete this homework?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      try {
                                        await _homeworkRepo.deleteHomework(
                                          h.id,
                                        );
                                        _loadHomeworks();
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Failed to delete: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit),
                                    title: Text('Edit Homework'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'close',
                                  enabled: h.status != 'closed',
                                  child: const ListTile(
                                    leading: Icon(Icons.lock_outline),
                                    title: Text('Close Homework'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('Delete Homework'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
