import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/academy/domain/models/academy_models.dart';
import 'package:flutter_application_1/features/academy/presentation/screens/academy_screens.dart';

void main() {
  group('Academy Core Presentation Widget Tests', () {
    testWidgets('StudentListWidget renders student list cards', (
      WidgetTester tester,
    ) async {
      final students = [
        const Student(
          id: 'e1000000-0000-0000-0000-000000000001',
          profileId: 'd0000000-0000-0000-0000-000000000001',
          studentCode: 'STU-001',
          primaryBranchId: '20000000-0000-0000-0000-000000000001',
          fullName: 'Alice Student',
          email: 'alice@academy.com',
          status: 'active',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StudentListWidget(students: students)),
        ),
      );

      expect(find.text('Alice Student'), findsOneWidget);
      expect(find.textContaining('STU-001'), findsOneWidget);
    });

    testWidgets('ParentListWidget renders parent cards', (
      WidgetTester tester,
    ) async {
      final parents = [
        const Parent(
          id: 'pr000000-0000-0000-0000-000000000001',
          profileId: 'p0000000-0000-0000-0000-000000000001',
          fullName: 'Bob Parent',
          email: 'bob@academy.com',
          status: 'active',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ParentListWidget(parents: parents)),
        ),
      );

      expect(find.text('Bob Parent'), findsOneWidget);
      expect(find.textContaining('bob@academy.com'), findsOneWidget);
    });

    testWidgets('TeacherListWidget renders teacher cards', (
      WidgetTester tester,
    ) async {
      final teachers = [
        const Teacher(
          id: 'b1000000-0000-0000-0000-000000000001',
          profileId: 'a0000000-0000-0000-0000-000000000001',
          primaryBranchId: '20000000-0000-0000-0000-000000000001',
          fullName: 'Dr. Turing',
          email: 'turing@academy.com',
          specialization: 'Computer Science',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TeacherListWidget(teachers: teachers)),
        ),
      );

      expect(find.text('Dr. Turing'), findsOneWidget);
      expect(find.textContaining('Computer Science'), findsOneWidget);
    });

    testWidgets('GroupListWidget renders group cards', (
      WidgetTester tester,
    ) async {
      final groups = [
        const GroupEntity(
          id: 'c1000000-0000-0000-0000-000000000001',
          name: 'CS Group A',
          code: 'GRP-CSA',
          subjectId: '30000000-0000-0000-0000-000000000001',
          branchId: '20000000-0000-0000-0000-000000000001',
          maxCapacity: 20,
          status: 'active',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GroupListWidget(groups: groups)),
        ),
      );

      expect(find.text('CS Group A (GRP-CSA)'), findsOneWidget);
      expect(find.textContaining('Max Capacity: 20'), findsOneWidget);
    });
  });
}
