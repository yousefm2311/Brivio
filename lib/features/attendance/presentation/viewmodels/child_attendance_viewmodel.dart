import 'package:flutter/material.dart';

class AttendanceRecord {
  final DateTime date;
  final String status; // 'present', 'absent', 'late'
  final String? note;

  AttendanceRecord({required this.date, required this.status, this.note});
}

class BehaviorRecord {
  final DateTime date;
  final String type; // 'positive', 'negative'
  final String description;
  final String teacher;

  BehaviorRecord({
    required this.date,
    required this.type,
    required this.description,
    required this.teacher,
  });
}

class ChildAttendanceViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<AttendanceRecord> _attendanceRecords = [];
  List<AttendanceRecord> get attendanceRecords => _attendanceRecords;

  List<BehaviorRecord> _behaviorRecords = [];
  List<BehaviorRecord> get behaviorRecords => _behaviorRecords;

  // Stats
  int get totalAbsences =>
      _attendanceRecords.where((r) => r.status == 'absent').length;
  int get totalTardiness =>
      _attendanceRecords.where((r) => r.status == 'late').length;

  ChildAttendanceViewModel() {
    _loadMockData();
  }

  Future<void> _loadMockData() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));

    final now = DateTime.now();

    _attendanceRecords = [
      AttendanceRecord(
        date: now.subtract(const Duration(days: 2)),
        status: 'absent',
        note: 'Sick leave',
      ),
      AttendanceRecord(
        date: now.subtract(const Duration(days: 5)),
        status: 'late',
        note: 'Traffic',
      ),
      AttendanceRecord(
        date: now.subtract(const Duration(days: 14)),
        status: 'absent',
        note: 'Family event',
      ),
    ];

    _behaviorRecords = [
      BehaviorRecord(
        date: now.subtract(const Duration(days: 1)),
        type: 'positive',
        description: 'Helped a classmate with math',
        teacher: 'Mr. Smith',
      ),
      BehaviorRecord(
        date: now.subtract(const Duration(days: 6)),
        type: 'negative',
        description: 'Talking during exam',
        teacher: 'Mrs. Johnson',
      ),
      BehaviorRecord(
        date: now.subtract(const Duration(days: 10)),
        type: 'positive',
        description: 'Excellent project presentation',
        teacher: 'Ms. Davis',
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }
}
