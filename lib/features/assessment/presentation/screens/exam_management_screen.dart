import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../domain/models/assessment_models.dart';
import 'exam_submissions_screen.dart';
import '../../../../core/services/report_generator_service.dart';

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
        SnackBar(content: Text(context.tr('Create an active group first.'))),
      );
      return;
    }
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Create New Exam')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Exam Title'),
                ),
              ),
              TextField(
                controller: durationCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Duration (Minutes)'),
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: passCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Passing Score'),
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
                    SnackBar(
                      content: Text(context.tr('Exam published successfully!')),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${context.tr('Creation failed')}: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(context.tr('Publish Exam')),
          ),
        ],
      ),
    );
  }

  void _showEditExamDialog(Exam e) {
    final titleCtrl = TextEditingController(text: e.title);
    final durationCtrl = TextEditingController(
      text: e.durationMinutes.toString(),
    );
    final passCtrl = TextEditingController(text: e.passScore.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Edit Exam')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Exam Title'),
                ),
              ),
              TextField(
                controller: durationCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Duration (Minutes)'),
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: passCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Passing Score'),
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
                    SnackBar(
                      content: Text(context.tr('Exam updated successfully!')),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (err) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${context.tr('Update failed')}: $err'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(context.tr('Save Changes')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportExamData() async {
    try {
      final service = ReportGeneratorService();
      final examDataList = _exams
          .map(
            (e) => {
              'title': e.title,
              'duration': e.durationMinutes,
              'pass_score': e.passScore,
              'status': e.status,
            },
          )
          .toList();

      final groupName = _selectedGroup?.name ?? 'Unknown Group';
      await service.generateExamReport(
        groupName: groupName,
        examData: examDataList,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Exam report generated.'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('Failed to generate report')}: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: context.tr('Exam & Quiz Management'),
      subtitle: context.tr(
        'Publish group exams with explicit duration and scoring.',
      ),
      icon: Icons.quiz,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: context.tr('Refresh'),
          onPressed: _loadExams,
        ),
        if (_selectedGroup != null)
          PortalAction(
            icon: Icons.quiz,
            label: context.tr('Add Exam'),
            onPressed: _showCreateExamDialog,
            primary: true,
          ),
        if (_selectedGroup != null)
          PortalAction(
            icon: Icons.picture_as_pdf,
            label: context.tr('Export Report'),
            onPressed: _exportExamData,
            primary: false,
          ),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: false,
        emptyTitle: context.tr('No exam data'),
        emptySubtitle: context.tr('Create an active group first.'),
        emptyIcon: Icons.quiz,
        onRetry: _loadExams,
        child: Column(
          children: [
            if (_groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<GroupEntity>(
                  initialValue: _selectedGroup,
                  decoration: InputDecoration(labelText: context.tr('Group')),
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
                  ? Center(child: Text(context.tr('No active groups found.')))
                  : _exams.isEmpty
                  ? Center(child: Text(context.tr('No exams found.')))
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
                              'Duration: ${e.durationMinutes} min | Pass Score: ${e.passScore} | Status: ${e.status.toUpperCase()}',
                          trailing: [
                            PortalStatusChip(status: e.status),
                            PopupMenuButton<String>(
                              tooltip: context.tr('Actions'),
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (value) async {
                                switch (value) {
                                  case 'submissions':
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (ctx) =>
                                            ExamSubmissionsScreen(exam: e),
                                      ),
                                    );
                                    break;
                                  case 'edit':
                                    _showEditExamDialog(e);
                                    break;
                                  case 'close':
                                    if (e.status == 'closed') return;
                                    try {
                                      await Supabase.instance.client
                                          .from('exams')
                                          .update({
                                            'status': 'closed',
                                            'updated_at': DateTime.now()
                                                .toIso8601String(),
                                          })
                                          .eq('id', e.id);
                                      _loadExams();
                                    } catch (err) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${context.tr('Failed to close')}: $err',
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
                                        title: Text(context.tr('Delete Exam')),
                                        content: Text(
                                          context.tr(
                                            'Are you sure you want to delete this exam?',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: Text(context.tr('Cancel')),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: Text(context.tr('Delete')),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      try {
                                        await Supabase.instance.client.rpc(
                                          'delete_exam',
                                          params: {'exam_id': e.id},
                                        );
                                        _loadExams();
                                      } catch (err) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${context.tr('Failed to delete')}: $err',
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
                                PopupMenuItem(
                                  value: 'submissions',
                                  child: ListTile(
                                    leading: const Icon(Icons.people),
                                    title: Text(context.tr('View Submissions')),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: const Icon(Icons.edit),
                                    title: Text(context.tr('Edit Exam')),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'close',
                                  enabled: e.status != 'closed',
                                  child: ListTile(
                                    leading: const Icon(Icons.lock_outline),
                                    title: Text(context.tr('Close Exam')),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: const Icon(Icons.delete_outline),
                                    title: Text(context.tr('Delete Exam')),
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
