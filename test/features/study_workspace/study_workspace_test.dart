import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/study_workspace/domain/models/study_workspace_models.dart';
import 'package:flutter_application_1/features/study_workspace/presentation/screens/study_workspace_screen.dart';

void main() {
  const lesson = StudyLessonSummary(
    id: 'lesson-test',
    title: 'Published lesson',
    pathName: 'Assigned subject',
    unitName: 'Published unit',
    progressPercentage: 42,
    estimatedMinutes: 35,
    lastPage: 6,
    totalPages: 18,
    xp: 120,
    hasPdf: true,
    hasCodePlayground: true,
  );

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('StudyWorkspaceScreen renders real workspace states', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: StudyWorkspaceScreen(lesson: lesson)),
    );
    await tester.pumpAndSettle();

    expect(find.text('PDF'), findsWidgets);
    expect(find.text('Notebook'), findsOneWidget);
    expect(find.text('Code'), findsOneWidget);
    expect(
      find.text('No PDF resource has been published for this lesson yet.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run preview'));
    await tester.pump();

    expect(find.textContaining('Preview runner'), findsOneWidget);
  });
}
