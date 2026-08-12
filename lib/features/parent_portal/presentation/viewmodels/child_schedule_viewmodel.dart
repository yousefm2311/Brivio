import 'package:flutter/material.dart';

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
}

class ChildScheduleViewModel extends ChangeNotifier {
  final List<ScheduleEvent> todaySchedule = [
    ScheduleEvent(
      title: 'Mathematics',
      time: '08:00 AM - 09:30 AM',
      description: 'Room 101 - Prof. Smith',
      color: Colors.blueAccent,
    ),
    ScheduleEvent(
      title: 'Science Lab',
      time: '09:45 AM - 11:15 AM',
      description: 'Lab 3 - Mrs. Davis',
      color: Colors.green,
    ),
    ScheduleEvent(
      title: 'Lunch Break',
      time: '11:15 AM - 12:00 PM',
      description: 'Cafeteria',
      color: Colors.orangeAccent,
    ),
    ScheduleEvent(
      title: 'History',
      time: '12:00 PM - 01:30 PM',
      description: 'Room 204 - Mr. Johnson',
      color: Colors.purpleAccent,
    ),
  ];

  final List<ScheduleEvent> upcomingExams = [
    ScheduleEvent(
      title: 'Midterm Mathematics',
      time: 'Oct 15, 2026 - 09:00 AM',
      description: 'Chapters 1 to 5',
      color: Colors.redAccent,
    ),
    ScheduleEvent(
      title: 'Science Final',
      time: 'Oct 20, 2026 - 10:00 AM',
      description: 'All topics',
      color: Colors.redAccent,
    ),
  ];

  final List<ScheduleEvent> holidays = [
    ScheduleEvent(
      title: 'Thanksgiving Break',
      time: 'Nov 26 - Nov 27, 2026',
      description: 'School Closed',
      color: Colors.teal,
    ),
    ScheduleEvent(
      title: 'Winter Vacation',
      time: 'Dec 20, 2026 - Jan 3, 2027',
      description: 'School Closed',
      color: Colors.teal,
    ),
  ];
}
