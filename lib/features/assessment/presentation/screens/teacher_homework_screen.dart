import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';

class TeacherHomeworkScreen extends StatefulWidget {
  final String teacherId;

  const TeacherHomeworkScreen({super.key, required this.teacherId});

  @override
  State<TeacherHomeworkScreen> createState() => _TeacherHomeworkScreenState();
}

class _TeacherHomeworkScreenState extends State<TeacherHomeworkScreen> {
  late final SupabaseHomeworkRepository _homeworkRepo;
  late final SupabaseTeacherRepository _teacherRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Homework> _homeworks = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _homeworkRepo = SupabaseHomeworkRepository(wrapper);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _loadGroupsAndHomeworks();
  }

  Future<void> _loadGroupsAndHomeworks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      GroupEntity? selected;
      if (_selectedGroup == null) {
        selected = groups.isNotEmpty ? groups.first : null;
      } else {
        for (final group in groups) {
          if (group.id == _selectedGroup!.id) {
            selected = group;
            break;
          }
        }
      }
      final homeworks = selected == null
          ? <Homework>[]
          : await _homeworkRepo.fetchHomeworkForGroup(selected.id);

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _homeworks = homeworks;
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

  Future<void> _selectGroup(GroupEntity? group) async {
    setState(() => _selectedGroup = group);
    await _loadGroupsAndHomeworks();
  }

  void _showCreateHomeworkDialog() {
    final group = _selectedGroup;
    if (group == null) return;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ptsCtrl = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Create Homework for ${group.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Homework title'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Instructions'),
                maxLines: 2,
              ),
              TextField(
                controller: ptsCtrl,
                decoration: const InputDecoration(labelText: 'Max score'),
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
              if (titleCtrl.text.trim().isEmpty) return;
              final nav = Navigator.of(ctx);
              try {
                await Supabase.instance.client.rpc(
                  'create_homework_assignment',
                  params: {
                    'p_title': titleCtrl.text.trim(),
                    'p_description': descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                    'p_subject_id': group.subjectId,
                    'p_group_id': group.id,
                    'p_due_at': DateTime.now()
                        .add(const Duration(days: 7))
                        .toIso8601String(),
                    'p_max_score': double.tryParse(ptsCtrl.text) ?? 100.0,
                    'p_status': 'published',
                  },
                );
                nav.pop();
                await _loadGroupsAndHomeworks();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Homework published.')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Creation failed: $e')));
              }
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Homework Workspace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroupsAndHomeworks,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedGroup == null ? null : _showCreateHomeworkDialog,
        icon: const Icon(Icons.assignment),
        label: const Text('Create Homework'),
      ),
      body: Column(
        children: [
          _GroupPicker(
            groups: _groups,
            selectedGroup: _selectedGroup,
            onChanged: _selectGroup,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return _ErrorState(
        message: _errorMessage!,
        onRetry: _loadGroupsAndHomeworks,
      );
    }
    if (_selectedGroup == null) {
      return const Center(child: Text('No assigned groups found.'));
    }
    if (_homeworks.isEmpty) {
      return const Center(
        child: Text('No homework assignments published yet.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _homeworks.length,
      separatorBuilder: (ctx, i) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final h = _homeworks[i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.assignment)),
          title: Text(
            h.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Max Score: ${h.maxScore} | Due: ${h.dueAt.year}-${h.dueAt.month}-${h.dueAt.day} | Status: ${h.status.toUpperCase()}',
          ),
        );
      },
    );
  }
}

class _GroupPicker extends StatelessWidget {
  final List<GroupEntity> groups;
  final GroupEntity? selectedGroup;
  final ValueChanged<GroupEntity?> onChanged;

  const _GroupPicker({
    required this.groups,
    required this.selectedGroup,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<GroupEntity>(
        initialValue: selectedGroup,
        decoration: const InputDecoration(
          labelText: 'Assigned group',
          border: OutlineInputBorder(),
        ),
        items: groups
            .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
            .toList(),
        onChanged: groups.isEmpty ? null : onChanged,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
