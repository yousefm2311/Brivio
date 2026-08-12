import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/models/homework_models.dart';
import '../viewmodels/homework_viewmodel.dart';

class GradingScreen extends StatelessWidget {
  final HomeworkAssignment assignment;

  const GradingScreen({super.key, required this.assignment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Submissions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Consumer<HomeworkViewModel>(
        builder: (context, viewModel, child) {
          final submissions = viewModel.getSubmissionsForAssignment(assignment.id);

          if (submissions.isEmpty) {
            return const Center(child: Text('No submissions yet.'));
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Points: ${assignment.totalPoints}',
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: submissions.length,
                  itemBuilder: (context, index) {
                    final submission = submissions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            submission.studentName.substring(0, 1).toUpperCase(),
                            style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(submission.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Submitted: ${DateFormat('MMM d, hh:mm a').format(submission.submittedAt)}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        trailing: _buildStatusBadge(submission),
                        onTap: () {
                          _showGradingDialog(context, viewModel, submission);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(HomeworkSubmission submission) {
    if (submission.isGraded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${submission.score}/${assignment.totalPoints}',
          style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Needs Grading',
          style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold),
        ),
      );
    }
  }

  void _showGradingDialog(BuildContext context, HomeworkViewModel viewModel, HomeworkSubmission submission) {
    final scoreController = TextEditingController(text: submission.score?.toString() ?? '');
    final feedbackController = TextEditingController(text: submission.teacherFeedback ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Grade ${submission.studentName}'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.attachment, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Submission File (Mock)',
                        style: TextStyle(color: Colors.blue.shade600, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: scoreController,
                  decoration: InputDecoration(
                    labelText: 'Score (out of ${assignment.totalPoints})',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: feedbackController,
                  decoration: const InputDecoration(
                    labelText: 'Feedback (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final score = int.tryParse(scoreController.text);
                if (score != null) {
                  viewModel.gradeSubmission(submission.id, score, feedbackController.text);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600),
              child: const Text('Save Grade'),
            ),
          ],
        );
      },
    );
  }
}
