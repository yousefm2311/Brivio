import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';

class TeacherExamScreen extends StatefulWidget {
  final String teacherId;

  const TeacherExamScreen({super.key, required this.teacherId});

  @override
  State<TeacherExamScreen> createState() => _TeacherExamScreenState();
}

class _TeacherExamScreenState extends State<TeacherExamScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseExamRepository _examRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Exam> _exams = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _examRepo = SupabaseExamRepository(wrapper);
    _loadGroupsAndExams();
  }

  Future<void> _loadGroupsAndExams() async {
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
      final exams = selected == null
          ? <Exam>[]
          : await _examRepo.fetchExamsForGroup(selected.id);

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _exams = exams;
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
    await _loadGroupsAndExams();
  }

  void _showCreateExamDialog() {
    final group = _selectedGroup;
    if (group == null) return;

    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '60');
    final passCtrl = TextEditingController(text: '60');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${context.tr('Create Exam for')} ${group.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Exam title'),
                ),
              ),
              TextField(
                controller: durationCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Duration minutes'),
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: passCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Pass score'),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final nav = Navigator.of(ctx);
              try {
                await Supabase.instance.client.rpc(
                  'create_exam_assignment',
                  params: {
                    'p_title': titleCtrl.text.trim(),
                    'p_subject_id': group.subjectId,
                    'p_group_id': group.id,
                    'p_duration_minutes': int.tryParse(durationCtrl.text) ?? 60,
                    'p_pass_score': double.tryParse(passCtrl.text) ?? 60.0,
                    'p_status': 'published',
                  },
                );
                nav.pop();
                await _loadGroupsAndExams();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('Exam published.'))),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${context.tr('Creation failed')}: $e'),
                  ),
                );
              }
            },
            child: Text(context.tr('Publish')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Teacher Exam & Quiz Workspace')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroupsAndExams,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedGroup == null ? null : _showCreateExamDialog,
        icon: const Icon(Icons.quiz),
        label: Text(context.tr('Create Exam')),
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
      return _ErrorState(message: _errorMessage!, onRetry: _loadGroupsAndExams);
    }
    if (_selectedGroup == null) {
      return Center(child: Text(context.tr('No assigned groups found.')));
    }
    if (_exams.isEmpty) {
      return Center(child: Text(context.tr('No exams published yet.')));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _exams.length,
      separatorBuilder: (ctx, i) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final exam = _exams[i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.quiz)),
          title: Text(
            exam.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${context.tr('Duration')}: ${exam.durationMinutes} ${context.tr('min')} | ${context.tr('Pass Score')}: ${exam.passScore} | ${context.tr('Status')}: ${context.tr(exam.status)}',
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
        decoration: InputDecoration(
          labelText: context.tr('Assigned group'),
          border: const OutlineInputBorder(),
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
            ElevatedButton(
              onPressed: onRetry,
              child: Text(context.tr('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
