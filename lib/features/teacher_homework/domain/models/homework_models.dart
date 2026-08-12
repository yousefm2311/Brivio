class HomeworkAssignment {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final List<String> assignedClasses;
  final int totalPoints;

  HomeworkAssignment({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.assignedClasses,
    required this.totalPoints,
  });
}

class HomeworkSubmission {
  final String id;
  final String assignmentId;
  final String studentId;
  final String studentName;
  final DateTime submittedAt;
  final String fileUrl;
  final int? score;
  final String? teacherFeedback;

  HomeworkSubmission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
    required this.submittedAt,
    required this.fileUrl,
    this.score,
    this.teacherFeedback,
  });

  bool get isGraded => score != null;
}
