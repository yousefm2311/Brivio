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
    hasPdf: false,
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
    await pumpUntilFound(tester, find.text('Code'));

    expect(find.text('Board'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Code'), findsOneWidget);

    await tester.tap(find.text('Notes').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Smart Notebook'), findsOneWidget);

    await tester.tap(find.text('Code').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Run preview'));
    await tester.pump();

    expect(find.textContaining('Preview runner'), findsOneWidget);
  });
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .join(' | ');
  fail('Finder did not appear. Visible text: $visibleText');
}
