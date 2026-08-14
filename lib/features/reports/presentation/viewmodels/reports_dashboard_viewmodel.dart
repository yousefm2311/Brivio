import 'package:flutter/foundation.dart';

class ReportsDashboardViewModel extends ChangeNotifier {
  bool isLoading = false;

  final List<Map<String, dynamic>> studentsData = [
    {
      'name': 'Alice',
      'exam_score': 95,
      'homework_score': 100,
      'missing_assignments': 0,
    },
    {
      'name': 'Bob',
      'exam_score': 78,
      'homework_score': 85,
      'missing_assignments': 1,
    },
  ];

  final List<Map<String, dynamic>> attendanceData = [
    {'name': 'Alice', 'present': 20, 'absent': 0, 'absence_dates': ''},
    {
      'name': 'Bob',
      'present': 18,
      'absent': 2,
      'absence_dates': '2026-08-01, 2026-08-05',
    },
  ];

  final List<Map<String, dynamic>> financialData = [
    {
      'date': '2026-08-10',
      'description': 'Tuition Fee - Alice',
      'type': 'Inflow',
      'amount': 500,
      'notes': '',
    },
    {
      'date': '2026-08-11',
      'description': 'Office Supplies',
      'type': 'Outflow',
      'amount': -50,
      'notes': 'Stationery',
    },
  ];

  final List<Map<String, dynamic>> teacherData = [
    {'name': 'Mr. Smith', 'classes_taught': 5, 'avg_attendance': 95.5},
    {'name': 'Mrs. Doe', 'classes_taught': 3, 'avg_attendance': 98.0},
  ];

  final List<Map<String, dynamic>> parentsData = [
    {
      'name': 'Mr. & Mrs. Smith',
      'students': 'Alice, Charlie',
      'email': 'smith@example.com',
      'status': 'Active',
    },
    {
      'name': 'Mr. Doe',
      'students': 'Bob',
      'email': 'doe@example.com',
      'status': 'Inactive',
    },
  ];

  final List<Map<String, dynamic>> homeworkData = [
    {
      'group': 'Math 101',
      'total': 15,
      'completion_rate': '92%',
      'avg_score': 88,
    },
    {
      'group': 'Science 202',
      'total': 10,
      'completion_rate': '85%',
      'avg_score': 76,
    },
  ];

  final List<Map<String, dynamic>> curriculumData = [
    {
      'subject': 'Mathematics',
      'total_modules': 12,
      'completed_modules': 8,
      'progress': '66%',
    },
    {
      'subject': 'Physics',
      'total_modules': 10,
      'completed_modules': 5,
      'progress': '50%',
    },
  ];

  void loadData() {
    isLoading = true;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 500), () {
      isLoading = false;
      notifyListeners();
    });
  }
}
