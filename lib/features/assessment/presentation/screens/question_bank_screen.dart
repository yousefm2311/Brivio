import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';

class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
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

  void _showCreateQuestionDialog() {
    final textCtrl = TextEditingController();
    final ptsCtrl = TextEditingController(text: '5');
    String qType = 'multiple_choice';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Create Question'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Question Prompt / Text',
                    ),
                    maxLines: 2,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: qType,
                    decoration: const InputDecoration(
                      labelText: 'Question Type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'multiple_choice',
                        child: Text('Multiple Choice (MCQ)'),
                      ),
                      DropdownMenuItem(
                        value: 'true_false',
                        child: Text('True / False'),
                      ),
                      DropdownMenuItem(
                        value: 'short_answer',
                        child: Text('Short Answer'),
                      ),
                      DropdownMenuItem(
                        value: 'long_answer',
                        child: Text('Long Answer'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => qType = v);
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
                  if (textCtrl.text.trim().isEmpty) return;

                  final nav = Navigator.of(ctx);
                  try {
                    final q = Question(
                      id: '',
                      subjectId: '30000000-0000-0000-0000-000000000001',
                      questionType: QuestionTypeExtension.fromString(qType),
                      prompt: textCtrl.text.trim(),
                      defaultPoints: double.tryParse(ptsCtrl.text) ?? 5.0,
                    );

                    await _questionRepo.createQuestion(q, []);
                    nav.pop();
                    _loadQuestions();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Question created!'),
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
                child: const Text('Create Question'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Bank Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuestions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateQuestionDialog,
        icon: const Icon(Icons.help_outline),
        label: const Text('Add Question'),
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
          ? const Center(child: Text('No questions found in question bank.'))
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
