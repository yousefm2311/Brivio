enum QuestionType { multipleChoice, trueFalse, shortAnswer, longAnswer }

extension QuestionTypeExtension on QuestionType {
  String toDbValue() {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'multiple_choice';
      case QuestionType.trueFalse:
        return 'true_false';
      case QuestionType.shortAnswer:
        return 'short_answer';
      case QuestionType.longAnswer:
        return 'long_answer';
    }
  }

  static QuestionType fromString(String val) {
    switch (val) {
      case 'multiple_choice':
        return QuestionType.multipleChoice;
      case 'true_false':
        return QuestionType.trueFalse;
      case 'short_answer':
        return QuestionType.shortAnswer;
      case 'long_answer':
        return QuestionType.longAnswer;
      default:
        return QuestionType.multipleChoice;
    }
  }
}

class QuestionOption {
  final String id;
  final String questionId;
  final String text;
  final int orderNumber;
  final bool isCorrect;

  QuestionOption({
    required this.id,
    required this.questionId,
    required this.text,
    this.orderNumber = 1,
    this.isCorrect = false,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: json['id'] as String,
      questionId: json['question_id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      orderNumber: json['order_number'] as int? ?? 1,
      isCorrect: json['is_correct'] as bool? ?? false,
    );
  }
}

class Question {
  final String id;
  final String subjectId;
  final String? unitId;
  final String? lessonId;
  final QuestionType questionType;
  final String prompt;
  final String? explanation;
  final String difficulty;
  final double defaultPoints;
  final String status;
  final List<QuestionOption> options;

  Question({
    required this.id,
    required this.subjectId,
    this.unitId,
    this.lessonId,
    required this.questionType,
    required this.prompt,
    this.explanation,
    this.difficulty = 'medium',
    this.defaultPoints = 1.00,
    this.status = 'active',
    this.options = const [],
  });

  factory Question.fromJson(
    Map<String, dynamic> json, [
    List<QuestionOption> options = const [],
  ]) {
    return Question(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      unitId: json['unit_id'] as String?,
      lessonId: json['lesson_id'] as String?,
      questionType: QuestionTypeExtension.fromString(
        json['question_type'] as String? ?? 'multiple_choice',
      ),
      prompt: json['prompt'] as String? ?? '',
      explanation: json['explanation'] as String?,
      difficulty: json['difficulty'] as String? ?? 'medium',
      defaultPoints: (json['default_points'] as num? ?? 1.0).toDouble(),
      status: json['status'] as String? ?? 'active',
      options: options,
    );
  }
}

class Homework {
  final String id;
  final String title;
  final String? description;
  final String subjectId;
  final String? groupId;
  final DateTime dueAt;
  final double maxScore;
  final String status;

  Homework({
    required this.id,
    required this.title,
    this.description,
    required this.subjectId,
    this.groupId,
    required this.dueAt,
    this.maxScore = 100.0,
    this.status = 'published',
  });

  factory Homework.fromJson(Map<String, dynamic> json) {
    return Homework(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      subjectId: json['subject_id'] as String? ?? '',
      groupId: json['group_id'] as String?,
      dueAt:
          DateTime.tryParse(json['due_at'] as String? ?? '') ?? DateTime.now(),
      maxScore: (json['max_score'] as num? ?? 100.0).toDouble(),
      status: json['status'] as String? ?? 'published',
    );
  }
}

class Exam {
  final String id;
  final String title;
  final String? description;
  final String subjectId;
  final String? groupId;
  final int durationMinutes;
  final int maxAttempts;
  final double passScore;
  final String status;
  final String resultReleasePolicy;
  final List<Question> questions;

  Exam({
    required this.id,
    required this.title,
    this.description,
    required this.subjectId,
    this.groupId,
    required this.durationMinutes,
    this.maxAttempts = 1,
    this.passScore = 50.0,
    this.status = 'published',
    this.resultReleasePolicy = 'immediate',
    this.questions = const [],
  });

  factory Exam.fromJson(
    Map<String, dynamic> json, [
    List<Question> questions = const [],
  ]) {
    return Exam(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      subjectId: json['subject_id'] as String? ?? '',
      groupId: json['group_id'] as String?,
      durationMinutes: json['duration_minutes'] as int? ?? 30,
      maxAttempts: json['max_attempts'] as int? ?? 1,
      passScore: (json['pass_score'] as num? ?? 50.0).toDouble(),
      status: json['status'] as String? ?? 'published',
      resultReleasePolicy:
          json['result_release_policy'] as String? ?? 'immediate',
      questions: questions,
    );
  }
}

class ExamAttempt {
  final String id;
  final String examId;
  final String studentId;
  final int attemptNumber;
  final String status;
  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime? submittedAt;
  final double? score;
  final double maxScore;

  ExamAttempt({
    required this.id,
    required this.examId,
    required this.studentId,
    this.attemptNumber = 1,
    this.status = 'in_progress',
    required this.startedAt,
    required this.expiresAt,
    this.submittedAt,
    this.score,
    this.maxScore = 100.0,
  });

  factory ExamAttempt.fromJson(Map<String, dynamic> json) {
    return ExamAttempt(
      id: json['id'] as String,
      examId: json['exam_id'] as String,
      studentId: json['student_id'] as String,
      attemptNumber: json['attempt_number'] as int? ?? 1,
      status: json['status'] as String? ?? 'in_progress',
      startedAt:
          DateTime.tryParse(json['started_at'] as String? ?? '') ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now().add(const Duration(minutes: 30)),
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      maxScore: (json['max_score'] as num? ?? 100.0).toDouble(),
    );
  }
}
