import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/auth/domain/models/user_profile.dart';
import '../teacher_dashboard.dart';
import '../../../features/code_playground/presentation/screens/code_playground_screen.dart';
import 'dart:ui';

// Mock Models for ViewModel
class _ScheduleItem {
  final String time;
  final String title;
  final String location;
  final Color color;

  _ScheduleItem(this.time, this.title, this.location, this.color);
}

class _UpcomingClass {
  final String name;
  final String subject;
  final String students;
  final String time;
  final Color color;

  _UpcomingClass(this.name, this.subject, this.students, this.time, this.color);
}

class _QuickAction {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _QuickAction(this.title, this.icon, this.color, this.onTap);
}

// Mock ViewModel
class _HomeViewModel {
  final List<_ScheduleItem> schedule = [
    _ScheduleItem("08:00 AM", "Morning Assembly", "Main Hall", AppColors.info),
    _ScheduleItem("09:15 AM", "Advanced Mathematics", "Room 402", AppColors.teacherRole),
    _ScheduleItem("11:30 AM", "Physics Lab", "Lab 2", AppColors.warning),
    _ScheduleItem("01:00 PM", "Staff Meeting", "Conference Room", AppColors.success),
  ];

  final List<_UpcomingClass> upcomingClasses = [
    _UpcomingClass("Grade 12-A", "Mathematics", "24 Students", "Tomorrow, 09:00 AM", AppColors.teacherRole),
    _UpcomingClass("Grade 11-B", "Physics", "28 Students", "Tomorrow, 11:00 AM", AppColors.warning),
    _UpcomingClass("Grade 10-C", "Computer Science", "30 Students", "Wed, 08:30 AM", AppColors.info),
  ];

  List<_QuickAction> getQuickActions(BuildContext context, VoidCallback onNavigateToCode) {
    return [
      _QuickAction("Code Playground", Icons.code_rounded, AppColors.teacherRole, onNavigateToCode),
      _QuickAction("Create Exam", Icons.assignment_add, AppColors.warning, () {}),
      _QuickAction("Grade Book", Icons.grading_rounded, AppColors.error, () {}),
      _QuickAction("Attendance", Icons.how_to_reg_rounded, AppColors.success, () {}),
    ];
  }
}

class HomeTab extends StatefulWidget {
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
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  final _HomeViewModel _viewModel = _HomeViewModel();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teacherRole));
    }
    if (widget.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: PortalErrorBanner(message: widget.errorMessage!, onRetry: widget.onRetry),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          pinned: true,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: (isDark ? AppColors.darkBackground : AppColors.lightBackground).withValues(alpha: 0.7),
              ),
            ),
          ),
          title: Text(
            context.tr('Teacher Portal'),
            style: AppTypography.displaySmall(textPrimary).copyWith(fontWeight: FontWeight.w800, fontSize: 24),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: widget.onRetry,
              tooltip: context.tr('Refresh'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, textPrimary),
                const SizedBox(height: 32),
                _buildSectionTitle(context, 'Quick Actions', Icons.bolt_rounded, AppColors.warning),
                const SizedBox(height: 16),
                _buildQuickActions(context),
                const SizedBox(height: 32),
                _buildSectionTitle(context, 'Today\'s Schedule', Icons.today_rounded, AppColors.info),
                const SizedBox(height: 16),
                _buildScheduleList(context),
                const SizedBox(height: 32),
                _buildSectionTitle(context, 'Upcoming Classes', Icons.class_rounded, AppColors.teacherRole),
                const SizedBox(height: 16),
                _buildUpcomingClasses(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Color textPrimary) {
    return FadeInSlide(
      duration: const Duration(milliseconds: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${context.tr("Welcome back")},',
            style: AppTypography.titleMedium(textPrimary.withValues(alpha: 0.6)).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            widget.user?.fullName ?? "Educator",
            style: AppTypography.displayMedium(textPrimary).copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return FadeInSlide(
      duration: const Duration(milliseconds: 600),
      delay: const Duration(milliseconds: 100),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            context.tr(title),
            style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = _viewModel.getQuickActions(context, () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CodePlaygroundScreen()),
      );
    });

    return FadeInSlide(
      duration: const Duration(milliseconds: 600),
      delay: const Duration(milliseconds: 200),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 3 * 12) / 4;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: actions.map((action) => _buildQuickActionCard(context, action, itemWidth)).toList(),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, _QuickAction action, double width) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: action.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        child: GlassCard(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, color: action.color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                action.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleList(BuildContext context) {
    return Column(
      children: _viewModel.schedule.asMap().entries.map((e) {
        final index = e.key;
        final item = e.value;
        return FadeInSlide(
          duration: const Duration(milliseconds: 600),
          delay: Duration(milliseconds: 300 + (index * 100)),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ScheduleCard(item: item),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUpcomingClasses(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _viewModel.upcomingClasses.length,
        itemBuilder: (context, index) {
          final item = _viewModel.upcomingClasses[index];
          return FadeInSlide(
            duration: const Duration(milliseconds: 600),
            delay: Duration(milliseconds: 400 + (index * 100)),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _UpcomingClassCard(item: item),
            ),
          );
        },
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final _ScheduleItem item;

  const _ScheduleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GlassCard(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.titleMedium(isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    const SizedBox(width: 4),
                    Text(
                      item.location,
                      style: AppTypography.caption(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item.time,
              style: AppTypography.caption(item.color).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingClassCard extends StatelessWidget {
  final _UpcomingClass item;

  const _UpcomingClassCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SizedBox(
      width: 260,
      child: GlassCard(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.class_rounded, color: item.color, size: 20),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.darkBackground : AppColors.lightBackground).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.time,
                    style: AppTypography.caption(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary).copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              item.name,
              style: AppTypography.titleLarge(isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary).copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  item.subject,
                  style: AppTypography.caption(item.color).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Container(width: 4, height: 4, decoration: BoxDecoration(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(
                  item.students,
                  style: AppTypography.caption(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
