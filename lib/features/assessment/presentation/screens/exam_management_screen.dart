import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../domain/models/assessment_models.dart';
import 'exam_submissions_screen.dart';

class ExamManagementScreen extends StatefulWidget {
  const ExamManagementScreen({super.key});

  @override
  State<ExamManagementScreen> createState() => _ExamManagementScreenState();
}

class _ExamManagementScreenState extends State<ExamManagementScreen> {
  late final SupabaseGroupRepository _groupRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Exam> _exams = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _groupRepo = SupabaseGroupRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _groupRepo.fetchGroups(status: 'active');
      final selected = _selectedGroup ?? (groups.isEmpty ? null : groups.first);
      final res = selected == null
          ? <dynamic>[]
          : await Supabase.instance.client
                .from('exams')
                .select()
                .eq('group_id', selected.id)
                .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _groups = groups;
          _selectedGroup = selected;
          _exams = res
              .map((e) => Exam.fromJson(e as Map<String, dynamic>))
              .toList();
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

  void _showCreateExamDialog() {
    final selectedGroup = _selectedGroup;
    if (selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create an active group first.')),
      );
      return;
    }
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Exam'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Exam Title'),
              ),
              TextField(
                controller: durationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Duration (Minutes)',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Passing Score'),
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
              final duration = int.tryParse(durationCtrl.text);
              final passScore = double.tryParse(passCtrl.text);
              if (titleCtrl.text.trim().isEmpty ||
                  duration == null ||
                  duration <= 0 ||
                  passScore == null ||
                  passScore < 0) {
                return;
              }

              final nav = Navigator.of(ctx);
              try {
                await Supabase.instance.client.rpc(
                  'create_exam_assignment',
                  params: {
                    'p_title': titleCtrl.text.trim(),
                    'p_subject_id': selectedGroup.subjectId,
                    'p_group_id': selectedGroup.id,
                    'p_duration_minutes': duration,
                    'p_pass_score': passScore,
                    'p_status': 'published',
                  },
                );
                nav.pop();
                _loadExams();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Exam published successfully!'),
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
            child: const Text('Publish Exam'),
          ),
        ],
      ),
    );
  }

  void _showEditExamDialog(Exam e) {
    final titleCtrl = TextEditingController(text: e.title);
    final durationCtrl = TextEditingController(text: e.durationMinutes.toString());
    final passCtrl = TextEditingController(text: e.passScore.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Exam'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Exam Title'),
              ),
              TextField(
                controller: durationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Duration (Minutes)',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Passing Score'),
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
              final duration = int.tryParse(durationCtrl.text);
              final passScore = double.tryParse(passCtrl.text);
              if (titleCtrl.text.trim().isEmpty ||
                  duration == null ||
                  duration <= 0 ||
                  passScore == null ||
                  passScore < 0) {
                return;
              }

              final nav = Navigator.of(ctx);
              try {
                await Supabase.instance.client
                    .from('exams')
                    .update({
                      'title': titleCtrl.text.trim(),
                      'duration_minutes': duration,
                      'pass_score': passScore,
                    })
                    .eq('id', e.id);
                nav.pop();
                _loadExams();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Exam updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (err) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Update failed: $err'),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'Exam & Quiz Management',
      subtitle: 'Publish group exams with explicit duration and scoring.',
      icon: Icons.quiz,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'Refresh',
          onPressed: _loadExams,
        ),
        if (_selectedGroup != null)
          PortalAction(
            icon: Icons.quiz,
            label: 'Add Exam',
            onPressed: _showCreateExamDialog,
            primary: true,
          ),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: false,
        emptyTitle: 'No exam data',
        emptySubtitle: 'Create an active group first.',
        emptyIcon: Icons.quiz,
        onRetry: _loadExams,
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
                    _loadExams();
                  },
                ),
              ),
            Expanded(
              child: _selectedGroup == null
                  ? const Center(child: Text('No active groups found.'))
                  : _exams.isEmpty
                  ? const Center(child: Text('No exams found.'))
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _exams.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final e = _exams[i];
                        return PortalListCard(
                          icon: Icons.quiz,
                          accentColor: AppColors.adminRole,
                          title: e.title,
                          subtitle:
                              'Duration: ${e.durationMinutes} min | Pass Score: ${e.passScore}',
                          trailing: [
                            PortalStatusChip(status: e.status),
                            IconButton(
                              icon: const Icon(Icons.people, color: Colors.green),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => ExamSubmissionsScreen(exam: e),
                                  ),
                                );
                              },
                              tooltip: 'View Submissions',
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEditExamDialog(e),
                              tooltip: 'Edit Exam',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Exam'),
                                    content: const Text('Are you sure you want to delete this exam?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await Supabase.instance.client.rpc('delete_exam', params: {'exam_id': e.id});
                                    _loadExams();
                                  } catch (err) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to delete: $err')),
                                      );
                                    }
                                  }
                                }
                              },
                              tooltip: 'Delete Exam',
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
