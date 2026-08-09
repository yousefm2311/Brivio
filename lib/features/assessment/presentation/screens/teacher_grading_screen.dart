import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherGradingScreen extends StatefulWidget {
  final String teacherId;

  const TeacherGradingScreen({super.key, required this.teacherId});

  @override
  State<TeacherGradingScreen> createState() => _TeacherGradingScreenState();
}

class _TeacherGradingScreenState extends State<TeacherGradingScreen> {
  List<Map<String, dynamic>> _homeworkSubmissions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGradingQueue();
  }

  Future<void> _loadGradingQueue() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await Supabase.instance.client.rpc(
        'get_teacher_grading_queue',
        params: {'p_teacher_id': widget.teacherId},
      );

      if (mounted) {
        setState(() {
          _homeworkSubmissions = (res as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
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

  void _showGradeSubmissionDialog(Map<String, dynamic> submission) {
    final scoreCtrl = TextEditingController(text: '95');
    final feedbackCtrl = TextEditingController(text: 'Excellent solution!');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual Grading & Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scoreCtrl,
              decoration: const InputDecoration(labelText: 'Final Score'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: feedbackCtrl,
              decoration: const InputDecoration(labelText: 'Teacher Feedback'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final score = double.tryParse(scoreCtrl.text) ?? 90.0;
              try {
                await Supabase.instance.client.rpc(
                  'grade_homework_submission',
                  params: {
                    'p_submission_id': submission['id'],
                    'p_score': score,
                    'p_feedback': feedbackCtrl.text.trim().isEmpty
                        ? null
                        : feedbackCtrl.text.trim(),
                  },
                );

                nav.pop();
                _loadGradingQueue();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Grade & feedback submitted to student!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Grading failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Submit Grade'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submissions & Manual Grading Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGradingQueue,
          ),
        ],
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
                    onPressed: _loadGradingQueue,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _homeworkSubmissions.isEmpty
          ? const Center(
              child: Text('No pending submissions requiring manual grading.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _homeworkSubmissions.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final sub = _homeworkSubmissions[i];
                final isGraded = sub['status'] == 'graded';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isGraded
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    child: Icon(
                      Icons.grading,
                      color: isGraded ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text(
                    'Student: ${sub['student_full_name'] ?? "Learner"}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${sub['homework_title'] ?? "Homework"} | Status: ${(sub['status'] as String? ?? "submitted").toUpperCase()} | Score: ${sub['score'] ?? "Pending"}',
                  ),
                  trailing: isGraded
                      ? const Chip(
                          label: Text(
                            'GRADED',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          backgroundColor: Colors.green,
                        )
                      : ElevatedButton(
                          onPressed: () => _showGradeSubmissionDialog(sub),
                          child: const Text('Grade'),
                        ),
                );
              },
            ),
    );
  }
}
