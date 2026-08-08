import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/attendance/domain/models/attendance_models.dart';
import 'package:flutter_application_1/features/attendance/presentation/screens/attendance_screens.dart';

void main() {
  group('Attendance Engine Models & Widget Tests', () {
    test('ClassSession model parses JSON correctly', () {
      final json = {
        'id': 'a0000000-0000-0000-0000-000000000001',
        'group_id': 'c1000000-0000-0000-0000-000000000001',
        'session_date': '2026-08-08',
        'status': 'in_progress',
        'location': 'Room 101',
      };

      final sess = ClassSession.fromJson(json);
      expect(sess.groupId, equals('c1000000-0000-0000-0000-000000000001'));
      expect(sess.status, equals(SessionStatus.inProgress));
      expect(sess.location, equals('Room 101'));
    });

    test('AttendanceSummary calculates percentage correctly', () {
      final summary = AttendanceSummary(
        totalSessions: 10,
        presentCount: 8,
        absentCount: 1,
        lateCount: 1,
        excusedCount: 0,
        attendancePercentage: 88.0,
      );

      expect(summary.totalSessions, equals(10));
      expect(summary.attendancePercentage, equals(88.0));
    });

    testWidgets('AttendanceSummaryWidget renders stats correctly', (
      WidgetTester tester,
    ) async {
      final summary = AttendanceSummary(
        totalSessions: 5,
        presentCount: 4,
        absentCount: 1,
        lateCount: 0,
        excusedCount: 0,
        attendancePercentage: 80.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AttendanceSummaryWidget(summary: summary)),
        ),
      );

      expect(find.text('Attendance Summary'), findsOneWidget);
      expect(find.text('Rate: 80.0%'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
    });

    testWidgets(
      'AttendanceRosterScreen renders student list and roll call buttons',
      (WidgetTester tester) async {
        final sess = ClassSession(
          id: 'sess-1',
          groupId: 'grp-1',
          sessionDate: DateTime.now(),
          scheduledStartAt: DateTime.now(),
          scheduledEndAt: DateTime.now().add(const Duration(hours: 2)),
        );

        final records = [
          AttendanceRecord(
            id: 'rec-1',
            classSessionId: 'sess-1',
            studentId: 'e0000000-0000-0000-0000-000000000001',
            attendanceStatus: AttendanceStatus.present,
            markedAt: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: AttendanceRosterScreen(
              session: sess,
              initialRecords: records,
            ),
          ),
        );

        expect(find.text('Student ID: e0000000...'), findsOneWidget);
        expect(find.text('Save Roll Call'), findsOneWidget);
        expect(find.text('Finalize Roll Call'), findsOneWidget);
      },
    );
  });
}
