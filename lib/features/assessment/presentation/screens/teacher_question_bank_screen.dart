import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';

class TeacherQuestionBankScreen extends StatefulWidget {
  final String teacherId;

  const TeacherQuestionBankScreen({super.key, required this.teacherId});

  @override
  State<TeacherQuestionBankScreen> createState() =>
      _TeacherQuestionBankScreenState();
}

class _TeacherQuestionBankScreenState extends State<TeacherQuestionBankScreen> {
  late final SupabaseQuestionBankRepository _questionRepo;
  late final SupabaseTeacherRepository _teacherRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Question> _questions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _questionRepo = SupabaseQuestionBankRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _teacherRepo = SupabaseTeacherRepository(
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
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      final selected = _selectedGroup ?? (groups.isEmpty ? null : groups.first);
      final q = selected == null
          ? <Question>[]
          : await _questionRepo.fetchQuestionsForSubject(selected.subjectId);
      if (mounted) {
        setState(() {
          _groups = groups;
          _selectedGroup = selected;
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

  void _showCreateMcqDialog() {
    final selectedGroup = _selectedGroup;
    if (selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('No assigned teaching groups found.')),
        ),
      );
      return;
    }
    final promptCtrl = TextEditingController();
    final opt1Ctrl = TextEditingController();
    final opt2Ctrl = TextEditingController();
    final opt3Ctrl = TextEditingController();
    final opt4Ctrl = TextEditingController();
    int correctIdx = 0;
    final ptsCtrl = TextEditingController(text: '5');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(context.tr('Create MCQ Question with Answer Key')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: promptCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr(
                      'Question Prompt (e.g. What is 2 + 2?)',
                    ),
                  ),
                  maxLines: 2,
                ),
                TextField(
                  controller: opt1Ctrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Option 1'),
                  ),
                ),
                TextField(
                  controller: opt2Ctrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Option 2'),
                  ),
                ),
                TextField(
                  controller: opt3Ctrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Option 3'),
                  ),
                ),
                TextField(
                  controller: opt4Ctrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Option 4'),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: correctIdx,
                  decoration: InputDecoration(
                    labelText: context.tr('Correct Option (Answer Key)'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(context.tr('Option 1 is Correct')),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(context.tr('Option 2 is Correct')),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(context.tr('Option 3 is Correct')),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text(context.tr('Option 4 is Correct')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setStateDialog(() => correctIdx = v);
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
                if (promptCtrl.text.trim().isEmpty) return;

                final nav = Navigator.of(ctx);
                try {
                  final opts = [
                    QuestionOption(
                      id: '',
                      questionId: '',
                      text: opt1Ctrl.text.trim(),
                      isCorrect: correctIdx == 0,
                      orderNumber: 1,
                    ),
                    QuestionOption(
                      id: '',
                      questionId: '',
                      text: opt2Ctrl.text.trim(),
                      isCorrect: correctIdx == 1,
                      orderNumber: 2,
                    ),
                    QuestionOption(
                      id: '',
                      questionId: '',
                      text: opt3Ctrl.text.trim(),
                      isCorrect: correctIdx == 2,
                      orderNumber: 3,
                    ),
                    QuestionOption(
                      id: '',
                      questionId: '',
                      text: opt4Ctrl.text.trim(),
                      isCorrect: correctIdx == 3,
                      orderNumber: 4,
                    ),
                  ];

                  final q = Question(
                    id: '',
                    subjectId: selectedGroup.subjectId,
                    questionType: QuestionType.multipleChoice,
                    prompt: promptCtrl.text.trim(),
                    defaultPoints: double.tryParse(ptsCtrl.text) ?? 5.0,
                    options: opts,
                  );

                  await _questionRepo.createQuestion(q, opts);
                  nav.pop();
                  _loadQuestions();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.tr(
                            'MCQ Question & Answer Key saved to Question Bank!',
                          ),
                        ),
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
              child: Text(context.tr('Save MCQ Question')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Teacher Question Bank')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuestions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedGroup == null ? null : _showCreateMcqDialog,
        icon: const Icon(Icons.help_outline),
        label: Text(context.tr('Add MCQ Question')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${context.tr('Error')}: $_errorMessage',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadQuestions,
                    child: Text(context.tr('Retry')),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                if (_groups.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: DropdownButtonFormField<GroupEntity>(
                      initialValue: _selectedGroup,
                      decoration: InputDecoration(
                        labelText: context.tr('Teaching Group'),
                        border: const OutlineInputBorder(),
                      ),
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
                        _loadQuestions();
                      },
                    ),
                  ),
                Expanded(
                  child: _selectedGroup == null
                      ? Center(
                          child: Text(
                            context.tr('No assigned teaching groups found.'),
                          ),
                        )
                      : _questions.isEmpty
                      ? Center(
                          child: Text(
                            context.tr('No questions found in Question Bank.'),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _questions.length,
                          separatorBuilder: (ctx, i) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final q = _questions[i];
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.help_outline),
                              ),
                              title: Text(
                                q.prompt,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${context.tr('Type')}: ${context.tr(q.questionType.name)} | ${context.tr('Points')}: ${q.defaultPoints}',
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
