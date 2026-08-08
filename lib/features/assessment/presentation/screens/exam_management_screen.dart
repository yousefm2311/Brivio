import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/assessment_models.dart';

class ExamManagementScreen extends StatefulWidget {
  const ExamManagementScreen({super.key});

  @override
  State<ExamManagementScreen> createState() => _ExamManagementScreenState();
}

class _ExamManagementScreenState extends State<ExamManagementScreen> {
  List<Exam> _exams = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await Supabase.instance.client.from('exams').select();
      if (mounted) {
        setState(() {
          _exams = (res as List<dynamic>)
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
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '60');
    final passCtrl = TextEditingController(text: '60');

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
                decoration: const InputDecoration(
                  labelText: 'Exam Title (e.g. Midterm Exam)',
                ),
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
              if (titleCtrl.text.trim().isEmpty) return;

              final nav = Navigator.of(ctx);
              try {
                await Supabase.instance.client.from('exams').insert({
                  'subject_id': '30000000-0000-0000-0000-000000000001',
                  'title': titleCtrl.text.trim(),
                  'duration_minutes': int.tryParse(durationCtrl.text) ?? 60,
                  'pass_score': double.tryParse(passCtrl.text) ?? 60.0,
                  'max_score': 100,
                  'status': 'published',
                  'published_at': DateTime.now().toIso8601String(),
                });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam & Quiz Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadExams),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateExamDialog,
        icon: const Icon(Icons.quiz),
        label: const Text('Add Exam'),
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
                    onPressed: _loadExams,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _exams.isEmpty
          ? const Center(child: Text('No exams found.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _exams.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final e = _exams[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.quiz)),
                  title: Text(
                    e.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Duration: ${e.durationMinutes} min | Pass Score: ${e.passScore}',
                  ),
                );
              },
            ),
    );
  }
}
