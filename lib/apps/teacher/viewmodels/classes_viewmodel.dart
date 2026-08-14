import 'package:flutter/foundation.dart';

class Student {
  final String id;
  final String name;
  final String avatarUrl;
  final double attendanceRate;
  final double grade;

  Student({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.attendanceRate,
    required this.grade,
  });
}

class TeacherClass {
  final String id;
  final String name;
  final String time;
  final String room;
  final List<Student> students;

  TeacherClass({
    required this.id,
    required this.name,
    required this.time,
    required this.room,
    required this.students,
  });
}

class ClassesViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<TeacherClass> _classes = [];
  List<TeacherClass> get classes => _classes;

  void loadClasses() {
    _isLoading = true;
    notifyListeners();

    // Mock delay
    Future.delayed(const Duration(seconds: 1), () {
      _classes = [
        TeacherClass(
          id: 'c1',
          name: 'Advanced Mathematics',
          time: 'Mon, Wed 10:00 AM',
          room: 'Room 302',
          students: [
            Student(
              id: 's1',
              name: 'Alice Smith',
              avatarUrl: 'https://i.pravatar.cc/150?u=a042581f4e29026024d',
              attendanceRate: 95.0,
              grade: 92.5,
            ),
            Student(
              id: 's2',
              name: 'Bob Johnson',
              avatarUrl: 'https://i.pravatar.cc/150?u=a042581f4e29026704d',
              attendanceRate: 88.0,
              grade: 85.0,
            ),
            Student(
              id: 's3',
              name: 'Charlie Brown',
              avatarUrl: 'https://i.pravatar.cc/150?u=a04258114e29026702d',
              attendanceRate: 100.0,
              grade: 98.0,
            ),
          ],
        ),
        TeacherClass(
          id: 'c2',
          name: 'Physics 101',
          time: 'Tue, Thu 01:00 PM',
          room: 'Lab 4',
          students: [
            Student(
              id: 's4',
              name: 'David Lee',
              avatarUrl: 'https://i.pravatar.cc/150?u=a048581f4e29026701d',
              attendanceRate: 75.0,
              grade: 72.0,
            ),
            Student(
              id: 's5',
              name: 'Eve Davis',
              avatarUrl: 'https://i.pravatar.cc/150?u=a04258a2462d826712d',
              attendanceRate: 92.0,
              grade: 89.5,
            ),
          ],
        ),
        TeacherClass(
          id: 'c3',
          name: 'Computer Science',
          time: 'Fri 09:00 AM',
          room: 'Lab 1',
          students: [
            Student(
              id: 's6',
              name: 'Frank White',
              avatarUrl: 'https://i.pravatar.cc/150?u=a042581f4e29026024e',
              attendanceRate: 85.0,
              grade: 80.0,
            ),
            Student(
              id: 's7',
              name: 'Grace Hopper',
              avatarUrl: 'https://i.pravatar.cc/150?u=a042581f4e29026704e',
              attendanceRate: 100.0,
              grade: 100.0,
            ),
          ],
        ),
      ];
      _isLoading = false;
      notifyListeners();
    });
  }
}
