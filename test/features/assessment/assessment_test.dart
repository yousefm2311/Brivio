import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/assessment/domain/models/assessment_models.dart';
import 'package:flutter_application_1/features/assessment/presentation/screens/assessment_screens.dart';

void main() {
  group('Assessment Engine Models & Widget Tests', () {
    test('Question model parses JSON correctly', () {
      final json = {
        'id': '80000000-0000-0000-0000-000000000001',
        'subject_id': '30000000-0000-0000-0000-000000000001',
        'question_type': 'multiple_choice',
        'prompt': 'What is Binary Search complexity?',
        'difficulty': 'medium',
        'default_points': 5.0,
      };

      final q = Question.fromJson(json, [
        QuestionOption(
          id: '81000000-0000-0000-0000-000000000001',
          questionId: '80000000-0000-0000-0000-000000000001',
          text: 'O(log N)',
          isCorrect: true,
        ),
      ]);

      expect(q.prompt, equals('What is Binary Search complexity?'));
      expect(q.questionType, equals(QuestionType.multipleChoice));
      expect(q.options.length, equals(1));
      expect(q.options.first.text, equals('O(log N)'));
    });

    test('Exam model parses JSON correctly', () {
      final json = {
        'id': '95000000-0000-0000-0000-000000000001',
        'title': 'CS-101 Midterm',
        'subject_id': '30000000-0000-0000-0000-000000000001',
        'duration_minutes': 30,
        'max_attempts': 1,
        'pass_score': 50.0,
        'status': 'published',
        'result_release_policy': 'immediate',
      };

      final exam = Exam.fromJson(json);
      expect(exam.title, equals('CS-101 Midterm'));
      expect(exam.durationMinutes, equals(30));
      expect(exam.resultReleasePolicy, equals('immediate'));
    });

    testWidgets('QuestionBankWidget renders questions list', (
      WidgetTester tester,
    ) async {
      final questions = [
        Question(
          id: 'q-1',
          subjectId: 'sub-1',
          questionType: QuestionType.multipleChoice,
          prompt: 'What is Binary Search?',
          defaultPoints: 5.0,
          options: [
            QuestionOption(
              id: 'o-1',
              questionId: 'q-1',
              text: 'O(log N)',
              isCorrect: true,
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuestionBankWidget(questions: questions)),
        ),
      );

      expect(find.text('What is Binary Search?'), findsOneWidget);
      expect(
        find.text('Type: MULTIPLECHOICE | Points: 5.0 | Difficulty: medium'),
        findsOneWidget,
      );
    });

    testWidgets('ExamRunnerScreen renders timer and questions', (
      WidgetTester tester,
    ) async {
      final exam = Exam(
        id: 'exam-1',
        title: 'Midterm Exam',
        subjectId: 'sub-1',
        durationMinutes: 45,
        questions: [
          Question(
            id: 'q-1',
            subjectId: 'sub-1',
            questionType: QuestionType.multipleChoice,
            prompt: 'Question 1: What is Binary Search?',
            options: [
              QuestionOption(
                id: 'opt-1',
                questionId: 'q-1',
                text: 'O(log N)',
                isCorrect: true,
              ),
              QuestionOption(
                id: 'opt-2',
                questionId: 'q-1',
                text: 'O(N)',
                isCorrect: false,
              ),
            ],
          ),
        ],
      );

      final attempt = ExamAttempt(
        id: 'att-1',
        examId: 'exam-1',
        studentId: 'stud-1',
        startedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 45)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ExamRunnerScreen(exam: exam, attempt: attempt),
        ),
      );

      expect(find.text('Midterm Exam'), findsOneWidget);
      expect(find.text('45:00'), findsOneWidget);
      expect(find.text('Question 1: What is Binary Search?'), findsOneWidget);
      expect(find.text('O(log N)'), findsOneWidget);
      expect(find.text('O(N)'), findsOneWidget);
    });
  });
}
