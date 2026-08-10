import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/supabase_client_wrapper.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/components/buttons.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../features/assessment/data/repositories/supabase_assessment_repositories.dart';
import '../../../features/attendance/data/repositories/supabase_attendance_repositories.dart';
import '../../../features/attendance/domain/models/attendance_models.dart';
import '../../../features/assessment/presentation/screens/assessment_screens.dart';
import '../../../features/curriculum/domain/models/curriculum_models.dart';
import '../student_dashboard_models.dart';

class StudentGroupDetailsScreen extends StatefulWidget {
  final GroupEntity group;

  const StudentGroupDetailsScreen({super.key, required this.group});

  @override
  State<StudentGroupDetailsScreen> createState() => _StudentGroupDetailsScreenState();
}

class _StudentGroupDetailsScreenState extends State<StudentGroupDetailsScreen> {
  late final SupabaseClassSessionRepository _sessionRepo;

  List<StudentHomeworkItem> _homeworkList = [];
  List<StudentExamItem> _examList = [];
  List<ClassSession> _sessionList = [];
  List<Lesson> _lessonList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _sessionRepo = SupabaseClassSessionRepository(wrapper);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final hwResData = await Supabase.instance.client.rpc('get_student_homework_feed');
      final examResData = await Supabase.instance.client.rpc('get_student_exam_feed');
      
      final hwRes = (hwResData as List)
          .map((e) => StudentHomeworkItem.fromJson(e as Map<dynamic, dynamic>))
          .where((h) => h.homework.groupId == widget.group.id)
          .toList();
          
      final examRes = (examResData as List)
          .map((e) => StudentExamItem.fromJson(e as Map<dynamic, dynamic>))
          .where((x) => x.exam.groupId == widget.group.id)
          .toList();
          
      final sessionRes = await _sessionRepo.fetchSessionsForGroup(widget.group.id);
      
      List<Lesson> lessonRes = [];
      try {
        final lessonsData = await Supabase.instance.client
            .from('lessons')
            .select('*, units!inner(subject_id), lesson_resources(*)')
            .eq('units.subject_id', widget.group.subjectId)
            .eq('status', 'published')
            .order('order_number');
            
        lessonRes = (lessonsData as List).map((e) {
          final jsonMap = e as Map<String, dynamic>;
          final resourcesList = jsonMap['lesson_resources'] as List<dynamic>? ?? [];
          final resources = resourcesList.map((r) => LessonResource.fromJson(r as Map<String, dynamic>)).toList();
          return Lesson.fromJson(jsonMap, resources);
        }).toList();
      } catch (e) {
        debugPrint('Error fetching curriculum: $e');
      }
      
      if (mounted) {
        setState(() {
          _homeworkList = hwRes;
          _examList = examRes;
          _sessionList = sessionRes;
          _lessonList = lessonRes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          title: Text(widget.group.name, style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800)),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: context.tr('Files & Lectures')),
              Tab(text: context.tr('Homework')),
              Tab(text: context.tr('Exams')),
              Tab(text: context.tr('Attendance')),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
                children: [
                  _buildFilesTab(isDark, textPrimary, textSecondary),
                  _buildHomeworkTab(isDark, textPrimary, textSecondary),
                  _buildExamsTab(isDark, textPrimary, textSecondary),
                  _buildAttendanceTab(isDark, textPrimary, textSecondary),
                ],
              ),
      ),
    );
  }

  Future<void> _submitHomework(StudentHomeworkItem item) async {
    if (item.homework.questions.isNotEmpty) {
      final Map<String, String> currentAnswers = {};
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HomeworkRunnerScreen(
          homework: item.homework,
          onOptionSelected: (qId, oId) => currentAnswers[qId] = oId,
          onSubmit: () async {
            try {
              await Supabase.instance.client.rpc(
                'submit_homework_mcq',
                params: {
                  'p_homework_id': item.homework.id,
                  'p_answers': currentAnswers,
                },
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Homework submitted.'))));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
              }
            }
          },
        ),
      ));
      await _loadData();
      return;
    }

    final textCtrl = TextEditingController();
    final attachCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${context.tr('Submit')} ${item.homework.title}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: textCtrl, decoration: InputDecoration(labelText: context.tr('Answer / notes'), alignLabelWithHint: true), minLines: 4, maxLines: 8),
              const SizedBox(height: 12),
              TextField(controller: attachCtrl, decoration: InputDecoration(labelText: context.tr('Attachment URL'), prefixIcon: const Icon(Icons.link)), keyboardType: TextInputType.url),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.upload_file), label: Text(context.tr('Submit'))),
        ],
      ),
    );
    if (submitted != true) { textCtrl.dispose(); attachCtrl.dispose(); return; }
    try {
      await Supabase.instance.client.rpc('submit_homework_text', params: {
        'p_homework_id': item.homework.id,
        'p_submission_text': textCtrl.text.trim(),
        'p_attachment_url': attachCtrl.text.trim().isEmpty ? null : attachCtrl.text.trim(),
      });
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Homework submitted.'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
    } finally {
      textCtrl.dispose();
      attachCtrl.dispose();
    }
  }

  Widget _buildHomeworkTab(bool isDark, Color textPrimary, Color textSecondary) {
    if (_homeworkList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_turned_in_rounded, size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(context.tr('No Homework'), style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(context.tr('You have no pending assignments here.'), style: AppTypography.bodyMedium(textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _homeworkList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final hw = _homeworkList[index];
        return GlassCard(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hw.homework.title, style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${context.tr("Max Score")}: ${hw.homework.maxScore}', style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                child: PrimaryButton(
                  text: hw.isSubmitted ? context.tr('Retry / Edit') : context.tr('Start'),
                  color: hw.isSubmitted ? AppColors.info : AppColors.primary,
                  onPressed: () => _submitHomework(hw),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilesTab(bool isDark, Color textPrimary, Color textSecondary) {
    if (_lessonList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_rounded, size: 64, color: AppColors.info.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(context.tr('No Group Files'), style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(context.tr('Lectures and materials will appear here.'), style: AppTypography.bodyMedium(textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _lessonList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final lesson = _lessonList[index];
        return GlassCard(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_lesson_rounded, color: AppColors.info, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title, style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.w700)),
                    if (lesson.estimatedDurationMinutes != null) ...[
                      const SizedBox(height: 4),
                      Text('${lesson.estimatedDurationMinutes} mins', style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w600)),
                    ],
                    if (lesson.resources.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: lesson.resources.map((res) {
                          return ActionChip(
                            avatar: const Icon(Icons.insert_drive_file, size: 16),
                            label: Text(res.title),
                            onPressed: () async {
                              final url = Supabase.instance.client.storage
                                  .from(res.bucket)
                                  .getPublicUrl(res.objectPath);
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startExam(StudentExamItem item) async {
    final groupId = item.exam.groupId;
    if (groupId == null) return;
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final repo = SupabaseExamRepository(wrapper);
      final exams = await repo.fetchExamsForGroup(groupId);
      final exam = exams.firstWhere((e) => e.id == item.exam.id);
      final attempt = await repo.startExam(exam.id);
      if (!mounted) return;
      
      // We push the ExamRunnerScreen from assessment_screens.dart
      // Import missing? We need to import assessment_screens.dart at top.
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ExamRunnerScreen(
          exam: exam,
          attempt: attempt,
          onOptionSelected: (qId, oId) => repo.saveExamAnswer(attemptId: attempt.id, questionId: qId, selectedOptionId: oId),
          onSubmit: () async {
            await repo.submitExamAttempt(attempt.id);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exam failed: $e')));
    }
  }

  Future<void> _requestExamReset(StudentExamItem item) async {
    final reasonCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Request Exam Reset')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('If you encountered an issue, explain why you need a reset.')),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, decoration: InputDecoration(labelText: context.tr('Reason')), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Submit Request'))),
        ],
      ),
    );

    if (submitted != true) return;

    try {
      await Supabase.instance.client.rpc('request_exam_reset', params: {
        'p_exam_id': item.exam.id,
        'p_reason': reasonCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Reset request submitted.')), backgroundColor: Colors.green));
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.tr("Failed to submit request")}: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildExamsTab(bool isDark, Color textPrimary, Color textSecondary) {
    if (_examList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_rounded, size: 64, color: AppColors.error.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(context.tr('No Exams'), style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(context.tr('No exams are currently active for this group.'), style: AppTypography.bodyMedium(textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _examList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final exam = _examList[index];
        return GlassCard(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.timer_outlined, color: AppColors.error, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exam.exam.title, style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${context.tr("Duration")}: ${exam.exam.durationMinutes} ${context.tr("min")}', style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              SizedBox(
                width: 140,
                child: Builder(builder: (context) {
                  if (exam.canStart) {
                    return PrimaryButton(
                      text: context.tr('Start Exam'),
                      onPressed: () => _startExam(exam),
                      color: AppColors.primary,
                    );
                  } else if (exam.resetRequestStatus == 'pending') {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                      ),
                      child: Center(
                        child: Text(
                          context.tr('Waiting for Approval'),
                          style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  } else if (exam.resetRequestStatus == 'rejected') {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                      ),
                      child: Center(
                        child: Text(
                          context.tr('Reset Rejected'),
                          style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  } else {
                    return PrimaryButton(
                      text: context.tr('Request Reset'),
                      onPressed: () => _requestExamReset(exam),
                      color: AppColors.error,
                    );
                  }
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttendanceTab(bool isDark, Color textPrimary, Color textSecondary) {
    if (_sessionList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_rounded, size: 64, color: AppColors.warning.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(context.tr('No Sessions'), style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(context.tr('No attendance records found.'), style: AppTypography.bodyMedium(textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _sessionList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = _sessionList[index];
        return GlassCard(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_note_rounded, color: AppColors.warning, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${context.tr("Session")} - ${session.location ?? ""}', style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(session.sessionDate.toLocal().toString().split(" ")[0], style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (session.status == SessionStatus.completed ? AppColors.success : AppColors.info).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  session.status.name.toUpperCase(),
                  style: AppTypography.caption(session.status == SessionStatus.completed ? AppColors.success : AppColors.info).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
