import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';

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
        title: Text(context.tr('Manual Grading & Feedback')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scoreCtrl,
              decoration: InputDecoration(labelText: context.tr('Final Score')),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: feedbackCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Teacher Feedback'),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Cancel')),
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
                    SnackBar(
                      content: Text(
                        context.tr('Grade & feedback submitted to student!'),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${context.tr('Grading failed')}: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(context.tr('Submit Grade')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Submissions & Manual Grading Queue')),
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
                    '${context.tr('Error')}: $_errorMessage',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadGradingQueue,
                    child: Text(context.tr('Retry')),
                  ),
                ],
              ),
            )
          : _homeworkSubmissions.isEmpty
          ? Center(
              child: Text(
                context.tr('No pending submissions requiring manual grading.'),
              ),
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
                    '${context.tr('Student')}: ${sub['student_full_name'] ?? context.tr("Learner")}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${sub['homework_title'] ?? context.tr("Homework")} | ${context.tr('Status')}: ${context.tr((sub['status'] as String? ?? "submitted"))} | ${context.tr('Score')}: ${sub['score'] ?? context.tr("Pending")}',
                  ),
                  trailing: isGraded
                      ? Chip(
                          label: Text(
                            context.tr('graded'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                          backgroundColor: Colors.green,
                        )
                      : ElevatedButton(
                          onPressed: () => _showGradeSubmissionDialog(sub),
                          child: Text(context.tr('Grade')),
                        ),
                );
              },
            ),
    );
  }
}
