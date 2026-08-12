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
import 'student_submissions_screen.dart';

class TeacherExamScreen extends StatefulWidget {
  final String teacherId;

  const TeacherExamScreen({super.key, required this.teacherId});

  @override
  State<TeacherExamScreen> createState() => _TeacherExamScreenState();
}

class _TeacherExamScreenState extends State<TeacherExamScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseExamRepository _examRepo;
  late final SupabaseQuestionBankRepository _questionRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Exam> _exams = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _attemptStatusLabel(BuildContext context, String? status) {
    switch (status) {
      case 'in_progress':
        return context.tr('In progress');
      case 'submitted':
        return context.tr('Submitted');
      case 'graded':
        return context.tr('Graded');
      case 'expired':
        return context.tr('Expired');
      default:
        final value = status?.trim();
        return value == null || value.isEmpty ? context.tr('Unknown') : value;
    }
  }

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _examRepo = SupabaseExamRepository(wrapper);
    _questionRepo = SupabaseQuestionBankRepository(wrapper);
    _loadGroupsAndExams();
  }

  Future<void> _loadGroupsAndExams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      GroupEntity? selected;
      if (_selectedGroup == null) {
        selected = groups.isNotEmpty ? groups.first : null;
      } else {
        for (final group in groups) {
          if (group.id == _selectedGroup!.id) {
            selected = group;
            break;
          }
        }
      }
      final exams = selected == null
          ? <Exam>[]
          : await _examRepo.fetchExamsForGroup(selected.id);

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _exams = exams;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectGroup(GroupEntity? group) async {
    setState(() => _selectedGroup = group);
    await _loadGroupsAndExams();
  }

  void _showCreateExamDialog() {
    final group = _selectedGroup;
    if (group == null) return;

    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '60');
    final passCtrl = TextEditingController(text: '60');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${context.tr('Create Exam for')} ${group.name}',
                    style: AppTypography.displaySmall(textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: context.tr('Exam title'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: durationCtrl,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: context.tr('Duration minutes'),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passCtrl,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: context.tr('Pass score'),
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
                          if (titleCtrl.text.trim().isEmpty) return;
                          final nav = Navigator.of(ctx);
                          try {
                            await Supabase.instance.client.rpc(
                              'create_exam_assignment',
                              params: {
                                'p_title': titleCtrl.text.trim(),
                                'p_subject_id': group.subjectId,
                                'p_group_id': group.id,
                                'p_duration_minutes':
                                    int.tryParse(durationCtrl.text) ?? 60,
                                'p_pass_score':
                                    double.tryParse(passCtrl.text) ?? 60.0,
                                'p_status': 'published',
                              },
                            );
                            nav.pop();
                            await _loadGroupsAndExams();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr('Exam published.')),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${context.tr('Creation failed')}: $e',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: Text(context.tr('Publish')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showManageQuestionsBottomSheet(Exam exam) async {
    final group = _selectedGroup;
    if (group == null) return;

    final Set<String> initiallyLinkedIds = exam.questions
        .map((q) => q.id)
        .toSet();
    final Set<String> currentSelectedIds = Set<String>.from(initiallyLinkedIds);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
        final textColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: FutureBuilder<List<Question>>(
                future: _questionRepo.fetchQuestionsForSubject(group.subjectId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading questions: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final allQuestions = snapshot.data ?? [];
                  if (allQuestions.isEmpty) {
                    return Center(
                      child: Text(
                        context.tr('No questions found in Question Bank.'),
                        style: TextStyle(color: textColor),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          '${context.tr('Manage Questions for')} ${exam.title}',
                          style: AppTypography.displaySmall(textColor),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${currentSelectedIds.length} ${context.tr('Selected')}',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  if (currentSelectedIds.length ==
                                      allQuestions.length) {
                                    currentSelectedIds.clear();
                                  } else {
                                    currentSelectedIds.addAll(
                                      allQuestions.map((q) => q.id),
                                    );
                                  }
                                });
                              },
                              child: Text(
                                currentSelectedIds.length == allQuestions.length
                                    ? context.tr('Deselect All')
                                    : context.tr('Select All'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: allQuestions.length,
                          itemBuilder: (context, index) {
                            final q = allQuestions[index];
                            final isLinked = currentSelectedIds.contains(q.id);

                            return ListTile(
                              title: Text(
                                q.prompt,
                                style: TextStyle(color: textColor),
                              ),
                              subtitle: Text(
                                '${context.tr(q.questionType.name)} | ${q.defaultPoints} ${context.tr('pts')}',
                              ),
                              trailing: Checkbox(
                                value: isLinked,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  if (val == null) return;
                                  setModalState(() {
                                    if (val) {
                                      currentSelectedIds.add(q.id);
                                    } else {
                                      currentSelectedIds.remove(q.id);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setModalState(() => isSaving = true);
                                  try {
                                    final additions = currentSelectedIds
                                        .difference(initiallyLinkedIds);
                                    final removals = initiallyLinkedIds
                                        .difference(currentSelectedIds);

                                    for (final id in additions) {
                                      final q = allQuestions.firstWhere(
                                        (q) => q.id == id,
                                      );
                                      await _examRepo.linkQuestion(
                                        exam.id,
                                        q.id,
                                        q.defaultPoints,
                                      );
                                    }
                                    for (final id in removals) {
                                      await _examRepo.unlinkQuestion(
                                        exam.id,
                                        id,
                                      );
                                    }

                                    await _loadGroupsAndExams();
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (ctx.mounted) {
                                      setModalState(() => isSaving = false);
                                    }
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(context.tr('Save & Close')),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showExamAttemptsDialog(Exam exam) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final subtitleColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    List<Map<String, dynamic>> attempts = [];
    try {
      final res = await Supabase.instance.client.rpc(
        'get_teacher_exam_attempts',
        params: {'p_exam_id': exam.id},
      );
      attempts = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching attempts: $e');
    }

    if (!context.mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${context.tr('Student Attempts')} - ${exam.title}',
                style: AppTypography.titleLarge(textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (attempts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    context.tr('No attempts yet.'),
                    style: AppTypography.bodyMedium(subtitleColor),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: attempts.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final att = attempts[i];
                      final studentName =
                          att['student_name']?.toString().trim().isNotEmpty ==
                              true
                          ? att['student_name'].toString()
                          : context.tr('Unknown Student');
                      final studentCode = att['student_code']?.toString();
                      final statusLabel = _attemptStatusLabel(
                        context,
                        att['status']?.toString(),
                      );
                      final studentId = att['student_id']?.toString();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          studentName,
                          style: AppTypography.bodyMedium(textColor),
                        ),
                        subtitle: Text(
                          '${studentCode == null || studentCode.isEmpty ? '' : '$studentCode | '}${context.tr('Score')}: ${att['score'] ?? 0} / ${att['max_score'] ?? 0} | ${context.tr('Status')}: $statusLabel',
                          style: AppTypography.caption(subtitleColor),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentSubmissionsScreen(
                                initialSubmission: {
                                  'id': att['id'],
                                  'assessment_type': 'exam',
                                  'assessment_id': exam.id,
                                  'student_id': att['student_id'],
                                  'score': att['score'],
                                  'teacher_feedback': att['teacher_feedback'],
                                },
                                onGraded: () {
                                  _loadGroupsAndExams();
                                },
                              ),
                            ),
                          );
                        },
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: AppColors.error,
                          ),
                          tooltip: context.tr('Reset Attempt'),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => AlertDialog(
                                title: Text(context.tr('Reset Exam')),
                                content: Text(
                                  '${context.tr('Are you sure you want to reset the exam for')} $studentName?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: Text(context.tr('Cancel')),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                    ),
                                    onPressed: () => Navigator.pop(c, true),
                                    child: Text(context.tr('Reset')),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && studentId != null) {
                              try {
                                await Supabase.instance.client.rpc(
                                  'reset_student_exam_attempt',
                                  params: {
                                    'p_exam_id': exam.id,
                                    'p_student_id': studentId,
                                  },
                                );
                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.tr('Exam reset successfully'),
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Reset failed: $e')),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  context.tr('Close'),
                  style: TextStyle(color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteExam(Exam exam) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete Exam')),
        content: Text(context.tr('Delete this exam and its attempts?')),
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
      await _examRepo.deleteExam(exam.id);
      await _loadGroupsAndExams();
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
          onRefresh: _loadGroupsAndExams,
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
                            onPressed: _loadGroupsAndExams,
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
                              labelText: context.tr('Assigned group'),
                              border: InputBorder.none,
                            ),
                            items: _groups
                                .map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(
                                      g.name,
                                      style: TextStyle(color: textColor),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _groups.isEmpty ? null : _selectGroup,
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
                            context.tr('No assigned groups found.'),
                            style: AppTypography.bodyMedium(subtitleColor),
                          ),
                        ),
                      )
                    else if (_exams.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            context.tr('No exams published yet.'),
                            style: AppTypography.bodyMedium(subtitleColor),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((ctx, i) {
                            final exam = _exams[i];
                            return FadeInSlide(
                              duration: Duration(milliseconds: 300 + (i * 50)),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: GlassCard(
                                  padding: EdgeInsets.zero,
                                  child: InkWell(
                                    onTap: () => _showExamAttemptsDialog(exam),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: AppColors.primary
                                                .withValues(alpha: 0.2),
                                            child: const Icon(
                                              Icons.quiz,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  exam.title,
                                                  style:
                                                      AppTypography.titleMedium(
                                                        textColor,
                                                      ).copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${context.tr('Duration')}: ${exam.durationMinutes} ${context.tr('min')} | ${context.tr('Pass Score')}: ${exam.passScore} | ${context.tr('Status')}: ${context.tr(exam.status)}',
                                                  style: AppTypography.caption(
                                                    subtitleColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  '${exam.questions.length} ${context.tr('Questions')}',
                                                  style: AppTypography.caption(
                                                    AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit_document,
                                              color: AppColors.primary,
                                            ),
                                            tooltip: context.tr(
                                              'Manage Questions',
                                            ),
                                            onPressed: () =>
                                                _showManageQuestionsBottomSheet(
                                                  exam,
                                                ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: AppColors.error,
                                            ),
                                            tooltip: context.tr('Delete Exam'),
                                            onPressed: () => _deleteExam(exam),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }, childCount: _exams.length),
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
              onPressed: _showCreateExamDialog,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.quiz),
              label: Text(context.tr('Create Exam')),
            ),
          ),
      ],
    );
  }
}
