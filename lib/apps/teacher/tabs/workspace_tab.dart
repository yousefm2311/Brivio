import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../features/assessment/presentation/screens/teacher_exam_screen.dart';
import '../../../features/assessment/presentation/screens/teacher_grading_screen.dart';
import '../../../features/assessment/presentation/screens/teacher_homework_screen.dart';
import '../../../features/assessment/presentation/screens/teacher_question_bank_screen.dart';
import '../../../features/attendance/presentation/screens/teacher_attendance_screen.dart';
import '../../../features/study_workspace/presentation/screens/study_replay_screen.dart';

class WorkspaceTab extends StatefulWidget {
  final String teacherId;

  const WorkspaceTab({super.key, required this.teacherId});

  @override
  State<WorkspaceTab> createState() => _WorkspaceTabState();
}

class _WorkspaceTabState extends State<WorkspaceTab> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Column(
      children: [
        Container(
          color: bgColor,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInSlide(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  context.tr('Workspace'),
                  style: AppTypography.displaySmall(textPrimary).copyWith(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
              ),
              const SizedBox(height: 16),
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 100),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    isScrollable: true,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: textPrimary,
                    unselectedLabelColor: textPrimary.withValues(alpha: 0.5),
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                    unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                    tabs: [
                      Tab(text: context.tr('Questions')),
                      Tab(text: context.tr('Homework')),
                      Tab(text: context.tr('Exams')),
                      Tab(text: context.tr('Attendance')),
                      Tab(text: context.tr('Grading')),
                      Tab(text: context.tr('Replay')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              TeacherQuestionBankScreen(teacherId: widget.teacherId),
              TeacherHomeworkScreen(teacherId: widget.teacherId),
              TeacherExamScreen(teacherId: widget.teacherId),
              TeacherAttendanceScreen(teacherId: widget.teacherId),
              TeacherGradingScreen(teacherId: widget.teacherId),
              StudyReplayScreen(teacherId: widget.teacherId),
            ],
          ),
        ),
      ],
    );
  }
}
