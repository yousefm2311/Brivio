import 'package:flutter/foundation.dart';

class ExamModel {
  final String id;
  final String title;
  final String subject;
  final String status;
  final int totalQuestions;
  final DateTime dueDate;

  ExamModel({
    required this.id,
    required this.title,
    required this.subject,
    required this.status,
    required this.totalQuestions,
    required this.dueDate,
  });
}

class QuestionBankModel {
  final String id;
  final String name;
  final String subject;
  final int questionCount;

  QuestionBankModel({
    required this.id,
    required this.name,
    required this.subject,
    required this.questionCount,
  });
}

class TeacherExamsViewModel extends ChangeNotifier {
  List<ExamModel> _exams = [];
  List<QuestionBankModel> _questionBanks = [];
  bool _isLoading = false;

  List<ExamModel> get exams => _exams;
  List<QuestionBankModel> get questionBanks => _questionBanks;
  bool get isLoading => _isLoading;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    // Mock delay
    await Future.delayed(const Duration(milliseconds: 800));

    _questionBanks = [
      QuestionBankModel(
        id: 'qb1',
        name: 'Algebra Fundamentals',
        subject: 'Math',
        questionCount: 45,
      ),
      QuestionBankModel(
        id: 'qb2',
        name: 'World War II History',
        subject: 'History',
        questionCount: 120,
      ),
      QuestionBankModel(
        id: 'qb3',
        name: 'Physics Mechanics',
        subject: 'Physics',
        questionCount: 65,
      ),
    ];

    _exams = [
      ExamModel(
        id: 'e1',
        title: 'Midterm Algebra Exam',
        subject: 'Math',
        status: 'Draft',
        totalQuestions: 20,
        dueDate: DateTime.now().add(const Duration(days: 7)),
      ),
      ExamModel(
        id: 'e2',
        title: 'History Pop Quiz',
        subject: 'History',
        status: 'Published',
        totalQuestions: 10,
        dueDate: DateTime.now().add(const Duration(days: 2)),
      ),
      ExamModel(
        id: 'e3',
        title: 'Physics Final',
        subject: 'Physics',
        status: 'Grading',
        totalQuestions: 50,
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }
}
