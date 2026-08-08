import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';

class TeacherQuestionBankScreen extends StatefulWidget {
  const TeacherQuestionBankScreen({super.key});

  @override
  State<TeacherQuestionBankScreen> createState() =>
      _TeacherQuestionBankScreenState();
}

class _TeacherQuestionBankScreenState extends State<TeacherQuestionBankScreen> {
  late final SupabaseQuestionBankRepository _questionRepo;
  List<Question> _questions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _questionRepo = SupabaseQuestionBankRepository(
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
      final q = await _questionRepo.fetchQuestionsForSubject(
        '30000000-0000-0000-0000-000000000001',
      );
      if (mounted) {
        setState(() {
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
    final promptCtrl = TextEditingController();
    final opt1Ctrl = TextEditingController(text: '2');
    final opt2Ctrl = TextEditingController(text: '3');
    final opt3Ctrl = TextEditingController(text: '4');
    final opt4Ctrl = TextEditingController(text: '5');
    int correctIdx = 2; // Option 3 is correct (value 4)
    final ptsCtrl = TextEditingController(text: '5');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Create MCQ Question with Answer Key'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: promptCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Question Prompt (e.g. What is 2 + 2?)',
                  ),
                  maxLines: 2,
                ),
                TextField(
                  controller: opt1Ctrl,
                  decoration: const InputDecoration(labelText: 'Option 1'),
                ),
                TextField(
                  controller: opt2Ctrl,
                  decoration: const InputDecoration(labelText: 'Option 2'),
                ),
                TextField(
                  controller: opt3Ctrl,
                  decoration: const InputDecoration(labelText: 'Option 3'),
                ),
                TextField(
                  controller: opt4Ctrl,
                  decoration: const InputDecoration(labelText: 'Option 4'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: correctIdx,
                  decoration: const InputDecoration(
                    labelText: 'Correct Option (Answer Key)',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text('Option 1 is Correct'),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text('Option 2 is Correct'),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text('Option 3 is Correct'),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text('Option 4 is Correct'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setStateDialog(() => correctIdx = v);
                  },
                ),
                TextField(
                  controller: ptsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Default Points',
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
                    subjectId: '30000000-0000-0000-0000-000000000001',
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
                      const SnackBar(
                        content: Text(
                          'MCQ Question & Answer Key saved to Question Bank!',
                        ),
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
              child: const Text('Save MCQ Question'),
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
        title: const Text('Teacher Question Bank'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuestions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateMcqDialog,
        icon: const Icon(Icons.help_outline),
        label: const Text('Add MCQ Question'),
      ),
      body: _isLoading
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
                    onPressed: _loadQuestions,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _questions.isEmpty
          ? const Center(child: Text('No questions found in Question Bank.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _questions.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final q = _questions[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.help_outline)),
                  title: Text(
                    q.prompt,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Type: ${q.questionType.name.toUpperCase()} | Points: ${q.defaultPoints}',
                  ),
                );
              },
            ),
    );
  }
}
