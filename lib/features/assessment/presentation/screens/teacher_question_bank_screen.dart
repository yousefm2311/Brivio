import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class TeacherQuestionBankScreen extends StatefulWidget {
  final String teacherId;

  const TeacherQuestionBankScreen({super.key, required this.teacherId});

  @override
  State<TeacherQuestionBankScreen> createState() =>
      _TeacherQuestionBankScreenState();
}

class _TeacherQuestionBankScreenState extends State<TeacherQuestionBankScreen> {
  late final SupabaseQuestionBankRepository _questionRepo;
  late final SupabaseTeacherRepository _teacherRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Question> _questions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _questionRepo = SupabaseQuestionBankRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _teacherRepo = SupabaseTeacherRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      final selected = _selectedGroup ?? (groups.isEmpty ? null : groups.first);
      final q = selected == null
          ? <Question>[]
          : await _questionRepo.fetchQuestionsForSubject(selected.subjectId);
      if (mounted) {
        setState(() {
          _groups = groups;
          _selectedGroup = selected;
          _questions = q;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showQuestionEditorDialog([Question? existingQuestion]) async {
    if (_selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('No assigned teaching groups found.')),
        ),
      );
      return;
    }

    QuestionType selectedType =
        existingQuestion?.questionType ?? QuestionType.multipleChoice;
    final promptCtrl = TextEditingController(text: existingQuestion?.prompt);
    final ptsCtrl = TextEditingController(
      text: existingQuestion?.defaultPoints.toString() ?? '5',
    );

    // MCQ/TF specific
    final opt1Ctrl = TextEditingController();
    final opt2Ctrl = TextEditingController();
    final opt3Ctrl = TextEditingController();
    final opt4Ctrl = TextEditingController();
    int correctIdx = 0;

    if (existingQuestion != null && existingQuestion.options.isNotEmpty) {
      if (selectedType == QuestionType.multipleChoice) {
        if (existingQuestion.options.isNotEmpty) {
          opt1Ctrl.text = existingQuestion.options[0].text;
        }
        if (existingQuestion.options.length > 1) {
          opt2Ctrl.text = existingQuestion.options[1].text;
        }
        if (existingQuestion.options.length > 2) {
          opt3Ctrl.text = existingQuestion.options[2].text;
        }
        if (existingQuestion.options.length > 3) {
          opt4Ctrl.text = existingQuestion.options[3].text;
        }
        correctIdx = existingQuestion.options.indexWhere((o) => o.isCorrect);
        if (correctIdx == -1) correctIdx = 0;
      } else if (selectedType == QuestionType.trueFalse) {
        correctIdx = existingQuestion.options.indexWhere((o) => o.isCorrect);
        if (correctIdx == -1) correctIdx = 0;
      }
    }

    // Short/Long answer specific
    final explanationCtrl = TextEditingController(
      text: existingQuestion?.explanation,
    );

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final surfaceColor = isDark
              ? AppColors.darkCard
              : AppColors.lightCard;
          final borderColor = isDark
              ? AppColors.darkBorder
              : AppColors.lightBorder;
          final textColor = isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary;

          return Dialog(
            backgroundColor: surfaceColor,
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: borderColor),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        existingQuestion == null
                            ? context.tr('Create Question')
                            : context.tr('Edit Question'),
                        style: AppTypography.displaySmall(textColor),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<QuestionType>(
                        initialValue: selectedType,
                        dropdownColor: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        decoration: InputDecoration(
                          labelText: context.tr('Question Type'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: QuestionType.multipleChoice,
                            child: Text(
                              context.tr('Multiple Choice'),
                              style: TextStyle(color: textColor),
                            ),
                          ),
                          DropdownMenuItem(
                            value: QuestionType.trueFalse,
                            child: Text(
                              context.tr('True / False'),
                              style: TextStyle(color: textColor),
                            ),
                          ),
                          DropdownMenuItem(
                            value: QuestionType.shortAnswer,
                            child: Text(
                              context.tr('Short Answer'),
                              style: TextStyle(color: textColor),
                            ),
                          ),
                          DropdownMenuItem(
                            value: QuestionType.longAnswer,
                            child: Text(
                              context.tr('Long Answer'),
                              style: TextStyle(color: textColor),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setStateDialog(() {
                              selectedType = v;
                              if (v == QuestionType.trueFalse) {
                                opt1Ctrl.text = 'True';
                                opt2Ctrl.text = 'False';
                                correctIdx = 0;
                              } else {
                                opt1Ctrl.clear();
                                opt2Ctrl.clear();
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: promptCtrl,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: context.tr('Question Prompt'),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),

                      if (selectedType == QuestionType.multipleChoice) ...[
                        TextField(
                          controller: opt1Ctrl,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: context.tr('Option 1'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: opt2Ctrl,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: context.tr('Option 2'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: opt3Ctrl,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: context.tr('Option 3'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: opt4Ctrl,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: context.tr('Option 4'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          initialValue: correctIdx,
                          dropdownColor: isDark
                              ? AppColors.darkCard
                              : AppColors.lightCard,
                          decoration: InputDecoration(
                            labelText: context.tr('Correct Option'),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 0,
                              child: Text(
                                context.tr('Option 1 is Correct'),
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 1,
                              child: Text(
                                context.tr('Option 2 is Correct'),
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text(
                                context.tr('Option 3 is Correct'),
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 3,
                              child: Text(
                                context.tr('Option 4 is Correct'),
                                style: TextStyle(color: textColor),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setStateDialog(() => correctIdx = v);
                          },
                        ),
                      ] else if (selectedType == QuestionType.trueFalse) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          initialValue: correctIdx,
                          dropdownColor: isDark
                              ? AppColors.darkCard
                              : AppColors.lightCard,
                          decoration: InputDecoration(
                            labelText: context.tr('Correct Option'),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 0,
                              child: Text(
                                context.tr('True is Correct'),
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 1,
                              child: Text(
                                context.tr('False is Correct'),
                                style: TextStyle(color: textColor),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setStateDialog(() => correctIdx = v);
                          },
                        ),
                      ] else ...[
                        TextField(
                          controller: explanationCtrl,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: context.tr('Model Answer / Explanation'),
                          ),
                          maxLines: 3,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: ptsCtrl,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: context.tr('Default Points'),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              context.tr('Cancel'),
                              style: TextStyle(color: textColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              if (promptCtrl.text.trim().isEmpty) return;
                              final nav = Navigator.of(ctx);
                              try {
                                List<QuestionOption> opts = [];

                                if (selectedType ==
                                    QuestionType.multipleChoice) {
                                  opts = [
                                    QuestionOption(
                                      id: '',
                                      questionId: '',
                                      text: opt1Ctrl.text.trim(),
                                      isCorrect: correctIdx == 0,
                                      orderNumber: 1,
                                    ),
                                    QuestionOption(
                                      id: '',
                                      questionId: '',
                                      text: opt2Ctrl.text.trim(),
                                      isCorrect: correctIdx == 1,
                                      orderNumber: 2,
                                    ),
                                    QuestionOption(
                                      id: '',
                                      questionId: '',
                                      text: opt3Ctrl.text.trim(),
                                      isCorrect: correctIdx == 2,
                                      orderNumber: 3,
                                    ),
                                    QuestionOption(
                                      id: '',
                                      questionId: '',
                                      text: opt4Ctrl.text.trim(),
                                      isCorrect: correctIdx == 3,
                                      orderNumber: 4,
                                    ),
                                  ];
                                } else if (selectedType ==
                                    QuestionType.trueFalse) {
                                  opts = [
                                    QuestionOption(
                                      id: '',
                                      questionId: '',
                                      text: 'True',
                                      isCorrect: correctIdx == 0,
                                      orderNumber: 1,
                                    ),
                                    QuestionOption(
                                      id: '',
                                      questionId: '',
                                      text: 'False',
                                      isCorrect: correctIdx == 1,
                                      orderNumber: 2,
                                    ),
                                  ];
                                }

                                final q = Question(
                                  id: existingQuestion?.id ?? '',
                                  subjectId: _selectedGroup!.subjectId,
                                  questionType: selectedType,
                                  prompt: promptCtrl.text.trim(),
                                  explanation:
                                      explanationCtrl.text.trim().isNotEmpty
                                      ? explanationCtrl.text.trim()
                                      : null,
                                  defaultPoints:
                                      double.tryParse(ptsCtrl.text) ?? 5.0,
                                  options: opts,
                                );

                                if (existingQuestion != null) {
                                  // Check if used in exams
                                  final res = await Supabase.instance.client
                                      .from('exam_questions')
                                      .select('exams(title)')
                                      .eq('question_id', existingQuestion.id);

                                  if (res.isNotEmpty) {
                                    // Ask to update all or save as new
                                    if (!mounted) return;
                                    final doUpdate = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: Text(context.tr('Warning')),
                                        content: Text(
                                          context.tr(
                                            'This question is used in active exams. Do you want to update it everywhere, or save this as a new question?',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: Text(
                                              context.tr('Save as New'),
                                            ),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: AppColors.error,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: Text(
                                              context.tr('Update Everywhere'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (doUpdate == true) {
                                      await _questionRepo.updateQuestion(
                                        q,
                                        opts,
                                      );
                                    } else {
                                      await _questionRepo.createQuestion(
                                        q,
                                        opts,
                                      );
                                    }
                                  } else {
                                    await _questionRepo.updateQuestion(q, opts);
                                  }
                                } else {
                                  await _questionRepo.createQuestion(q, opts);
                                }

                                nav.pop();
                                _loadQuestions();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.tr(
                                          'Question saved successfully!',
                                        ),
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${context.tr('Save failed')}: $e',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(
                              existingQuestion == null
                                  ? context.tr('Save Question')
                                  : context.tr('Update Question'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteQuestion(Question question) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete Question')),
        content: Text(context.tr('Delete this question from the bank?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _questionRepo.deleteQuestion(question.id);
      await _loadQuestions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('Delete failed')}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final subtitleColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadQuestions,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? ListView(
                  children: [
                    const SizedBox(height: 100),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${context.tr('Error')}: $_errorMessage',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadQuestions,
                            child: Text(context.tr('Retry')),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    if (_groups.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 4.0,
                            ),
                            child: DropdownButtonFormField<GroupEntity>(
                              initialValue: _selectedGroup,
                              dropdownColor: isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightCard,
                              decoration: InputDecoration(
                                labelText: context.tr('Teaching Group'),
                                border: InputBorder.none,
                              ),
                              items: _groups
                                  .map(
                                    (g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(
                                        '${g.name} (${g.code})',
                                        style: TextStyle(color: textColor),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (group) {
                                if (group == null) return;
                                setState(() => _selectedGroup = group);
                                _loadQuestions();
                              },
                            ),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    if (_selectedGroup == null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            context.tr('No assigned teaching groups found.'),
                            style: AppTypography.bodyMedium(subtitleColor),
                          ),
                        ),
                      )
                    else if (_questions.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            context.tr('No questions found in Question Bank.'),
                            style: AppTypography.bodyMedium(subtitleColor),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((ctx, i) {
                            final q = _questions[i];
                            return FadeInSlide(
                              duration: Duration(milliseconds: 300 + (i * 50)),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.primary
                                            .withValues(alpha: 0.2),
                                        child: const Icon(
                                          Icons.help_outline,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              q.prompt,
                                              style:
                                                  AppTypography.titleMedium(
                                                    textColor,
                                                  ).copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${context.tr('Type')}: ${context.tr(q.questionType.name)} | ${context.tr('Points')}: ${q.defaultPoints}',
                                              style: AppTypography.caption(
                                                subtitleColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          color: AppColors.primary,
                                        ),
                                        onPressed: () =>
                                            _showQuestionEditorDialog(q),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.error,
                                        ),
                                        onPressed: () => _deleteQuestion(q),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }, childCount: _questions.length),
                        ),
                      ),
                  ],
                ),
        ),
        if (_selectedGroup != null)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: () => _showQuestionEditorDialog(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(context.tr('Add Question')),
            ),
          ),
      ],
    );
  }
}
