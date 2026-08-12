import 'package:flutter/foundation.dart';
import '../../domain/models/attendance_models.dart';

class FastAttendanceStudent {
  final String id;
  final String name;
  final String? avatarUrl;
  AttendanceStatus? status;
  String? incidentRecord;

  FastAttendanceStudent({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.status,
    this.incidentRecord,
  });
}

class FastAttendanceViewModel extends ChangeNotifier {
  List<FastAttendanceStudent> students = [
    FastAttendanceStudent(id: '1', name: 'Alice Smith'),
    FastAttendanceStudent(id: '2', name: 'Bob Johnson'),
    FastAttendanceStudent(id: '3', name: 'Charlie Brown'),
    FastAttendanceStudent(id: '4', name: 'Diana Prince'),
    FastAttendanceStudent(id: '5', name: 'Evan Wright'),
  ];

  bool isLoading = false;

  void markAttendance(String studentId, AttendanceStatus status) {
    final index = students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      students[index].status = status;
      notifyListeners();
    }
  }

  void logIncident(String studentId, String incident) {
    final index = students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      students[index].incidentRecord = incident;
      notifyListeners();
    }
  }

  Future<void> submitAttendance() async {
    isLoading = true;
    notifyListeners();
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    isLoading = false;
    notifyListeners();
  }
}
