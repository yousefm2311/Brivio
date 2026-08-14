import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';

class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  late final SupabaseQuestionBankRepository _questionRepo;
  late final SupabaseSubjectRepository _subjectRepo;
  List<SubjectEntity> _subjects = [];
  SubjectEntity? _selectedSubject;
  List<Question> _questions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _questionRepo = SupabaseQuestionBankRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _subjectRepo = SupabaseSubjectRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final subjects = await _subjectRepo.fetchSubjects(status: 'active');
      final selected =
          _selectedSubject ?? (subjects.isEmpty ? null : subjects.first);
      final q = selected == null
          ? <Question>[]
          : await _questionRepo.fetchQuestionsForSubject(selected.id);
      if (mounted) {
        setState(() {
          _subjects = subjects;
          _selectedSubject = selected;
          _questions = q;
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

  void _showCreateQuestionDialog() {
    final selectedSubject = _selectedSubject;
    if (selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Create an active subject first.'))),
      );
      return;
    }
    final textCtrl = TextEditingController();
    final ptsCtrl = TextEditingController(text: '5');
    String qType = 'multiple_choice';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(context.tr('Create Question')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textCtrl,
                    decoration: InputDecoration(
                      labelText: context.tr('Question Prompt / Text'),
                    ),
                    maxLines: 2,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: qType,
                    decoration: InputDecoration(
                      labelText: context.tr('Question Type'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'multiple_choice',
                        child: Text(context.tr('Multiple Choice (MCQ)')),
                      ),
                      DropdownMenuItem(
                        value: 'true_false',
                        child: Text(context.tr('True / False')),
                      ),
                      DropdownMenuItem(
                        value: 'short_answer',
                        child: Text(context.tr('Short Answer')),
                      ),
                      DropdownMenuItem(
                        value: 'long_answer',
                        child: Text(context.tr('Long Answer')),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => qType = v);
                    },
                  ),
                  TextField(
                    controller: ptsCtrl,
                    decoration: InputDecoration(
                      labelText: context.tr('Default Points'),
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
                  if (textCtrl.text.trim().isEmpty) return;

                  final nav = Navigator.of(ctx);
                  try {
                    final q = Question(
                      id: '',
                      subjectId: selectedSubject.id,
                      questionType: QuestionTypeExtension.fromString(qType),
                      prompt: textCtrl.text.trim(),
                      defaultPoints: double.tryParse(ptsCtrl.text) ?? 5.0,
                    );

                    await _questionRepo.createQuestion(q, []);
                    nav.pop();
                    _loadQuestions();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr('Question created!')),
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
                child: Text(context.tr('Create Question')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditQuestionDialog(Question q) {
    final textCtrl = TextEditingController(text: q.prompt);
    final ptsCtrl = TextEditingController(text: q.defaultPoints.toString());
    String qType = q.questionType.toDbValue();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(context.tr('Edit Question')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textCtrl,
                    decoration: InputDecoration(
                      labelText: context.tr('Question Prompt / Text'),
                    ),
                    maxLines: 2,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: qType,
                    decoration: InputDecoration(
                      labelText: context.tr('Question Type'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'multiple_choice',
                        child: Text(context.tr('Multiple Choice (MCQ)')),
                      ),
                      DropdownMenuItem(
                        value: 'true_false',
                        child: Text(context.tr('True / False')),
                      ),
                      DropdownMenuItem(
                        value: 'short_answer',
                        child: Text(context.tr('Short Answer')),
                      ),
                      DropdownMenuItem(
                        value: 'long_answer',
                        child: Text(context.tr('Long Answer')),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => qType = v);
                    },
                  ),
                  TextField(
                    controller: ptsCtrl,
                    decoration: InputDecoration(
                      labelText: context.tr('Default Points'),
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
                  if (textCtrl.text.trim().isEmpty) return;

                  final nav = Navigator.of(ctx);
                  try {
                    await Supabase.instance.client
                        .from('questions')
                        .update({
                          'prompt': textCtrl.text.trim(),
                          'question_type': qType,
                          'default_points':
                              double.tryParse(ptsCtrl.text) ?? 5.0,
                        })
                        .eq('id', q.id);

                    nav.pop();
                    _loadQuestions();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr('Question updated!')),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${context.tr('Update failed')}: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Text(context.tr('Save Changes')),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: context.tr('Question Bank'),
      subtitle: context.tr('Create reusable assessment questions by subject.'),
      icon: Icons.help_outline,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: context.tr('Refresh'),
          onPressed: _loadQuestions,
        ),
        if (_selectedSubject != null)
          PortalAction(
            icon: Icons.help_outline,
            label: context.tr('Add Question'),
            onPressed: _showCreateQuestionDialog,
            primary: true,
          ),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: false,
        emptyTitle: context.tr('No question data'),
        emptySubtitle: context.tr('Create an active subject first.'),
        emptyIcon: Icons.help_outline,
        onRetry: _loadQuestions,
        child: Column(
          children: [
            if (_subjects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<SubjectEntity>(
                  initialValue: _selectedSubject,
                  decoration: InputDecoration(labelText: context.tr('Subject')),
                  items: _subjects
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text('${s.name} (${s.code})'),
                        ),
                      )
                      .toList(),
                  onChanged: (subject) {
                    if (subject == null) return;
                    setState(() => _selectedSubject = subject);
                    _loadQuestions();
                  },
                ),
              ),
            Expanded(
              child: _selectedSubject == null
                  ? Center(child: Text(context.tr('No active subjects found.')))
                  : _questions.isEmpty
                  ? Center(
                      child: Text(
                        context.tr('No questions found in question bank.'),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _questions.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final q = _questions[i];
                        return PortalListCard(
                          icon: Icons.help_outline,
                          accentColor: AppColors.adminRole,
                          title: q.prompt,
                          subtitle:
                              'Type: ${q.questionType.name.toUpperCase()} | Points: ${q.defaultPoints}',
                          trailing: [
                            PopupMenuButton<String>(
                              tooltip: context.tr('Actions'),
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  _showEditQuestionDialog(q);
                                  return;
                                }
                                if (value == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(
                                        context.tr('Delete Question'),
                                      ),
                                      content: Text(
                                        context.tr(
                                          'Are you sure you want to delete this question?',
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
                                      await _questionRepo.deleteQuestion(q.id);
                                      _loadQuestions();
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
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: const Icon(Icons.edit),
                                    title: Text(context.tr('Edit Question')),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: const Icon(Icons.delete_outline),
                                    title: Text(context.tr('Delete Question')),
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
