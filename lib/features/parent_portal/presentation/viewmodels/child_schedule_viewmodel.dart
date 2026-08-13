import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleEvent {
  final String title;
  final String time;
  final String description;
  final Color color;

  ScheduleEvent({
    required this.title,
    required this.time,
    required this.description,
    required this.color,
  });

  factory ScheduleEvent.fromScheduleRow(Map<String, dynamic> row) {
    final groupName = row['group_name']?.toString() ?? 'Group';
    final subjectName = row['subject_name']?.toString() ?? 'Class';
    final room =
        row['room_name']?.toString() ??
        row['location']?.toString() ??
        'Room not assigned';
    final status = row['status']?.toString() ?? 'scheduled';
    final start = _formatTime(row['start_time']?.toString());
    final end = _formatTime(row['end_time']?.toString());

    return ScheduleEvent(
      title: subjectName,
      time: '$start - $end',
      description: '$groupName · $room · $status',
      color: status == 'cancelled' ? Colors.redAccent : Colors.blueAccent,
    );
  }

  static String _formatTime(String? value) {
    if (value == null || value.length < 5) return '--:--';
    return value.substring(0, 5);
  }
}

class ChildScheduleViewModel extends ChangeNotifier {
  final List<ScheduleEvent> todaySchedule = [];
  final List<ScheduleEvent> upcomingExams = [];
  final List<ScheduleEvent> holidays = [];

  bool isLoading = false;
  String? errorMessage;

  Future<void> loadForChild(String studentId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final today = DateTime.now();
      final fromDate = DateTime(today.year, today.month, today.day);
      final toDate = fromDate.add(const Duration(days: 30));
      final response = await Supabase.instance.client.rpc(
        'get_parent_child_schedule',
        params: {
          'p_student_id': studentId,
          'p_from_date': _dateOnly(fromDate),
          'p_to_date': _dateOnly(toDate),
        },
      );

      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      todaySchedule
        ..clear()
        ..addAll(
          rows
              .where(
                (row) => row['session_date']?.toString() == _dateOnly(fromDate),
              )
              .map(ScheduleEvent.fromScheduleRow),
        );

      upcomingExams.clear();
      holidays.clear();
    } catch (e) {
      errorMessage = e.toString();
      todaySchedule.clear();
      upcomingExams.clear();
      holidays.clear();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  static String _dateOnly(DateTime value) {
    return value.toIso8601String().split('T').first;
  }
}
