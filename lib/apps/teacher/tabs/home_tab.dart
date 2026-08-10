import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/auth/domain/models/user_profile.dart';
import '../teacher_dashboard.dart';

class HomeTab extends StatelessWidget {
  final UserProfile? user;
  final bool isLoading;
  final String? errorMessage;
  final int assignedGroupsCount;
  final int openHomeworkCount;
  final int publishedExamsCount;
  final int gradingQueueCount;
  final int todaySessionsCount;
  final int savedBoardCount;
  final List<TeacherGroupAnalytics> groupAnalytics;
  final VoidCallback onRetry;
  final ValueChanged<int> onNavigate;

  const HomeTab({
    super.key,
    required this.user,
    required this.isLoading,
    this.errorMessage,
    required this.assignedGroupsCount,
    required this.openHomeworkCount,
    required this.publishedExamsCount,
    required this.gradingQueueCount,
    required this.todaySessionsCount,
    required this.savedBoardCount,
    required this.groupAnalytics,
    required this.onRetry,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          surfaceTintColor: Colors.transparent,
          pinned: true,
          title: Text(
            context.tr('Teacher Portal'),
            style: AppTypography.displaySmall(textPrimary).copyWith(fontWeight: FontWeight.w800, fontSize: 24),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: onRetry,
              tooltip: context.tr('Refresh'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        if (isLoading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.teacherRole)))
        else if (errorMessage != null)
          SliverFillRemaining(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: PortalErrorBanner(message: errorMessage!, onRetry: onRetry),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    '${context.tr("Welcome")}, ${user?.fullName ?? "Educator"}',
                    style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Metrics grid
                FadeInSlide(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 100),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildMetricCard(context, context.tr('Assigned Groups'), '$assignedGroupsCount', Icons.groups, AppColors.teacherRole, () => onNavigate(1)),
                      _buildMetricCard(context, context.tr('Today Sessions'), '$todaySessionsCount', Icons.today, AppColors.info, () => onNavigate(1)),
                      _buildMetricCard(context, context.tr('Open Homework'), '$openHomeworkCount', Icons.assignment, AppColors.warning, () => onNavigate(2)),
                      _buildMetricCard(context, context.tr('To Grade'), '$gradingQueueCount', Icons.grading, AppColors.error, () => onNavigate(2)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 200),
                  child: Text(
                    context.tr('Group Analytics'),
                    style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
                  ),
                ),
                const SizedBox(height: 16),
                
                if (groupAnalytics.isEmpty)
                  FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 300),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          context.tr('No group analytics available yet.'),
                          style: AppTypography.bodyMedium(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                      ),
                    ),
                  )
                else
                  ...groupAnalytics.asMap().entries.map((e) => FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 300 + (e.key * 100)),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _TeacherGroupAnalyticsCard(item: e.value),
                    ),
                  )),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: (MediaQuery.sizeOf(context).width - 40 - 12) / 2 - 16 - 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 12),
              Text(value, style: AppTypography.displaySmall(isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary).copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(title, style: AppTypography.caption(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary).copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherGroupAnalyticsCard extends StatelessWidget {
  final TeacherGroupAnalytics item;

  const _TeacherGroupAnalyticsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GlassCard(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.teacherRole.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insights_rounded, color: AppColors.teacherRole),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.groupName, style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (item.groupCode.isNotEmpty) item.groupCode,
                        '${item.studentCount} ${context.tr("students")}',
                      ].join(' | '),
                      style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PortalStatusChip(
                status: item.attendanceRate >= 85 ? 'healthy' : item.attendanceRate >= 65 ? 'watch' : 'risk',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AnalyticsMiniMetric(icon: Icons.event_available, label: context.tr('Attendance'), value: '${item.attendanceRate.toStringAsFixed(1)}%', color: AppColors.success),
              _AnalyticsMiniMetric(icon: Icons.cancel, label: context.tr('Absences'), value: item.absentCount.toString(), color: AppColors.error),
              _AnalyticsMiniMetric(icon: Icons.assignment_late, label: context.tr('Pending HW'), value: item.pendingHomeworkCount.toString(), color: AppColors.warning),
              _AnalyticsMiniMetric(icon: Icons.quiz, label: context.tr('Exam Avg'), value: '${item.averageExamScore.toStringAsFixed(1)}%', color: AppColors.info),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalyticsMiniMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AnalyticsMiniMetric({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.sizeOf(context).width - 40 - 32 - 16) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color)),
                Text(value, style: AppTypography.titleMedium(color).copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
