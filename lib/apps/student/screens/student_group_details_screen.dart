import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/supabase_client_wrapper.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/components/buttons.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../features/assessment/data/repositories/supabase_assessment_repositories.dart';
import '../../../features/assessment/domain/models/assessment_models.dart';
import '../../../features/attendance/data/repositories/supabase_attendance_repositories.dart';
import '../../../features/attendance/domain/models/attendance_models.dart';
import '../../../features/curriculum/data/repositories/supabase_curriculum_repositories.dart';
import '../../../features/curriculum/domain/models/curriculum_models.dart';

class StudentGroupDetailsScreen extends StatefulWidget {
  final GroupEntity group;

  const StudentGroupDetailsScreen({super.key, required this.group});

  @override
  State<StudentGroupDetailsScreen> createState() => _StudentGroupDetailsScreenState();
}

class _StudentGroupDetailsScreenState extends State<StudentGroupDetailsScreen> {
  late final SupabaseHomeworkRepository _homeworkRepo;
  late final SupabaseExamRepository _examRepo;
  late final SupabaseClassSessionRepository _sessionRepo;
  late final SupabaseSemesterRepository _semesterRepo;
  late final SupabaseUnitRepository _unitRepo;
  late final SupabaseLessonRepository _lessonRepo;

  List<Homework> _homeworkList = [];
  List<Exam> _examList = [];
  List<ClassSession> _sessionList = [];
  List<Lesson> _lessonList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _homeworkRepo = SupabaseHomeworkRepository(wrapper);
    _examRepo = SupabaseExamRepository(wrapper);
    _sessionRepo = SupabaseClassSessionRepository(wrapper);
    _semesterRepo = SupabaseSemesterRepository(wrapper);
    _unitRepo = SupabaseUnitRepository(wrapper);
    _lessonRepo = SupabaseLessonRepository(wrapper);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final hwRes = await _homeworkRepo.fetchHomeworkForGroup(widget.group.id);
      final examRes = await _examRepo.fetchExamsForGroup(widget.group.id);
      final sessionRes = await _sessionRepo.fetchSessionsForGroup(widget.group.id);
      
      List<Lesson> lessonRes = [];
      try {
        final sems = await _semesterRepo.fetchSemestersForSubject(widget.group.subjectId);
        if (sems.isNotEmpty) {
          final units = await _unitRepo.fetchUnitsForSemester(sems.first.id);
          if (units.isNotEmpty) {
            lessonRes = await _lessonRepo.fetchLessonsForUnit(units.first.id);
          }
        }
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
                    Text(hw.title, style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${context.tr("Max Score")}: ${hw.maxScore}', style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                child: PrimaryButton(
                  text: context.tr('Start'),
                  onPressed: () {},
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
                    ]
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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
                    Text(exam.title, style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${context.tr("Duration")}: ${exam.durationMinutes} ${context.tr("min")}', style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                child: PrimaryButton(
                  text: context.tr('Start'),
                  onPressed: () {},
                  color: AppColors.error,
                ),
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
