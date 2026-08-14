import 'package:flutter/foundation.dart';

class AttendanceReportsViewModel extends ChangeNotifier {
  bool isLoading = false;

  final List<Map<String, dynamic>> studentAttendance = [
    {
      'name': 'Alice Smith',
      'present': 45,
      'absent': 2,
      'absence_dates': '2026-08-01, 2026-08-05',
      'status': 'Excellent',
    },
    {
      'name': 'Bob Johnson',
      'present': 40,
      'absent': 7,
      'absence_dates': '2026-08-02, 2026-08-03',
      'status': 'Warning',
    },
    {
      'name': 'Charlie Davis',
      'present': 47,
      'absent': 0,
      'absence_dates': '',
      'status': 'Perfect',
    },
  ];

  final List<Map<String, dynamic>> teacherAttendance = [
    {
      'name': 'Mr. Anderson',
      'present': 50,
      'absent': 1,
      'absence_dates': '2026-07-20',
      'status': 'Good',
    },
    {
      'name': 'Mrs. Martinez',
      'present': 49,
      'absent': 2,
      'absence_dates': '2026-07-15, 2026-08-10',
      'status': 'Good',
    },
  ];

  final List<Map<String, dynamic>> staffAttendance = [
    {
      'name': 'John Doe (Admin)',
      'present': 55,
      'absent': 0,
      'absence_dates': '',
      'status': 'Perfect',
    },
    {
      'name': 'Jane Roe (Maintenance)',
      'present': 52,
      'absent': 3,
      'absence_dates': '2026-08-01, 2026-08-02',
      'status': 'Good',
    },
  ];

  void loadData() {
    isLoading = true;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 800), () {
      isLoading = false;
      notifyListeners();
    });
  }
}
