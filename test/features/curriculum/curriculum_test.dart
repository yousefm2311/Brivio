import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/curriculum/domain/models/curriculum_models.dart';
import 'package:flutter_application_1/features/curriculum/presentation/screens/curriculum_screens.dart';

void main() {
  group('Curriculum & Content Engine Unit & Widget Tests', () {
    test('Semester model parses JSON correctly', () {
      final json = {
        'id': '40000000-0000-0000-0000-000000000001',
        'subject_id': '30000000-0000-0000-0000-000000000001',
        'name': 'Fall 2026',
        'code': 'FALL-2026',
        'order_number': 1,
        'status': 'active',
      };

      final semester = Semester.fromJson(json);
      expect(semester.id, '40000000-0000-0000-0000-000000000001');
      expect(semester.name, 'Fall 2026');
      expect(semester.code, 'FALL-2026');
    });

    test('Lesson model parses JSON and resources correctly', () {
      final json = {
        'id': '60000000-0000-0000-0000-000000000001',
        'unit_id': '50000000-0000-0000-0000-000000000001',
        'title': '1.1 Video: What is an Algorithm?',
        'lesson_type': 'video',
        'order_number': 1,
        'status': 'published',
        'estimated_duration_minutes': 15,
      };

      final lesson = Lesson.fromJson(json);
      expect(lesson.id, '60000000-0000-0000-0000-000000000001');
      expect(lesson.lessonType, LessonType.video);
      expect(lesson.status, LessonStatus.published);
    });

    testWidgets('CurriculumHierarchyWidget renders semesters and lessons', (
      WidgetTester tester,
    ) async {
      final semesters = [
        const Semester(
          id: '40000000-0000-0000-0000-000000000001',
          subjectId: '30000000-0000-0000-0000-000000000001',
          name: 'Fall 2026',
          code: 'FALL-2026',
          orderNumber: 1,
          status: 'active',
        ),
      ];

      final units = [
        const Unit(
          id: '50000000-0000-0000-0000-000000000001',
          semesterId: '40000000-0000-0000-0000-000000000001',
          name: 'Unit 1: Algorithms',
          code: 'U1-ALG',
          orderNumber: 1,
          status: 'active',
        ),
      ];

      final lessons = [
        const Lesson(
          id: '60000000-0000-0000-0000-000000000001',
          unitId: '50000000-0000-0000-0000-000000000001',
          title: '1.1 Video: What is an Algorithm?',
          lessonType: LessonType.video,
          orderNumber: 1,
          status: LessonStatus.published,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurriculumHierarchyWidget(
              semesters: semesters,
              units: units,
              lessons: lessons,
            ),
          ),
        ),
      );

      expect(find.text('Fall 2026 (FALL-2026)'), findsOneWidget);
      expect(find.text('Unit 1: Algorithms (U1-ALG)'), findsOneWidget);
      expect(find.text('1.1 Video: What is an Algorithm?'), findsOneWidget);
    });
  });
}
