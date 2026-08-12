import 'package:flutter/foundation.dart';
import '../../domain/models/homework_models.dart';

class HomeworkViewModel extends ChangeNotifier {
  final List<HomeworkAssignment> _assignments = [
    HomeworkAssignment(
      id: 'a1',
      title: 'Math Worksheet - Chapter 5',
      description: 'Complete all exercises in Chapter 5. Show your work.',
      dueDate: DateTime.now().add(const Duration(days: 2)),
      assignedClasses: ['Class 10A', 'Class 10B'],
      totalPoints: 100,
    ),
    HomeworkAssignment(
      id: 'a2',
      title: 'Physics Lab Report',
      description: 'Write a comprehensive report on the pendulum experiment.',
      dueDate: DateTime.now().add(const Duration(days: 5)),
      assignedClasses: ['Class 11 Science'],
      totalPoints: 50,
    ),
  ];

  final List<HomeworkSubmission> _submissions = [
    HomeworkSubmission(
      id: 's1',
      assignmentId: 'a1',
      studentId: 'stu1',
      studentName: 'Alice Johnson',
      submittedAt: DateTime.now().subtract(const Duration(hours: 5)),
      fileUrl: 'https://example.com/alice_math.pdf',
    ),
    HomeworkSubmission(
      id: 's2',
      assignmentId: 'a1',
      studentId: 'stu2',
      studentName: 'Bob Smith',
      submittedAt: DateTime.now().subtract(const Duration(hours: 1)),
      fileUrl: 'https://example.com/bob_math.pdf',
      score: 85,
      teacherFeedback: 'Good work, but review exercise 4.',
    ),
  ];

  List<HomeworkAssignment> get assignments => _assignments;

  List<HomeworkSubmission> getSubmissionsForAssignment(String assignmentId) {
    return _submissions.where((s) => s.assignmentId == assignmentId).toList();
  }

  void createAssignment({
    required String title,
    required String description,
    required DateTime dueDate,
    required List<String> assignedClasses,
    required int totalPoints,
  }) {
    final newAssignment = HomeworkAssignment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      dueDate: dueDate,
      assignedClasses: assignedClasses,
      totalPoints: totalPoints,
    );
    _assignments.insert(0, newAssignment);
    notifyListeners();
  }

  void gradeSubmission(String submissionId, int score, String feedback) {
    final index = _submissions.indexWhere((s) => s.id == submissionId);
    if (index != -1) {
      final old = _submissions[index];
      _submissions[index] = HomeworkSubmission(
        id: old.id,
        assignmentId: old.assignmentId,
        studentId: old.studentId,
        studentName: old.studentName,
        submittedAt: old.submittedAt,
        fileUrl: old.fileUrl,
        score: score,
        teacherFeedback: feedback,
      );
      notifyListeners();
    }
  }
}
