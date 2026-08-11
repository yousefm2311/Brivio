import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

import '../../../core/localization/app_localizations.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../features/academy/presentation/screens/academy_screens.dart';
import '../../../features/payments/domain/models/payment_models.dart';
import '../../../features/study_workspace/domain/models/study_workspace_models.dart';
import '../../../features/code_playground/presentation/screens/code_playground_screen.dart';

String _formatMoney(int amountMinor, String currency) {
  final format = NumberFormat.currency(
    symbol: '$currency ',
    decimalDigits: 2,
  );
  return format.format(amountMinor / 100);
}

class HomeTab extends StatelessWidget {
  final String userName;
  final bool isLoading;
  final String? errorMessage;
  final StudentLearningSnapshot? snapshot;
  final List<GroupEntity> enrolledGroups;
  final FinancialSummary? financialSummary;
  final int unreadCount;
  final VoidCallback onRetry;
  final VoidCallback? onOpenWorkspace;
  final ValueChanged<int> onNavigate;

  const HomeTab({
    super.key,
    required this.userName,
    required this.isLoading,
    required this.errorMessage,
    required this.snapshot,
    required this.enrolledGroups,
    required this.financialSummary,
    required this.unreadCount,
    required this.onRetry,
    required this.onOpenWorkspace,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final nextLesson = snapshot?.nextLesson;
    final gamification = snapshot?.gamification;

    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      color: AppColors.primary,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Large Title App Bar ──
          SliverAppBar(
            backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            surfaceTintColor: Colors.transparent,
            floating: true,
            pinned: false,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 24, bottom: 8),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInSlide(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      context.tr('Good morning,'),
                      style: AppTypography.caption(textSecondary).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      userName.split(' ').first,
                      style: AppTypography.displayMedium(textPrimary).copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (errorMessage != null) ...[
                  PortalErrorBanner(message: errorMessage!, onRetry: onRetry),
                  const SizedBox(height: 16),
                ],

                // ── Next Lesson Hero (Glassmorphism) ──
                FadeInSlide(
                  duration: const Duration(milliseconds: 700),
                  delay: const Duration(milliseconds: 150),
                  child: _NextLessonHero(
                    isLoading: isLoading,
                    lesson: nextLesson,
                    gamification: gamification,
                    onOpen: onOpenWorkspace,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Code Playground Shortcut ──
                FadeInSlide(
                  duration: const Duration(milliseconds: 700),
                  delay: const Duration(milliseconds: 175),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CodePlaygroundScreen(),
                        ),
                      );
                    },
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.code, color: AppColors.primary, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Code Playground',
                                  style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Practice coding anytime',
                                  style: AppTypography.caption(textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Quick Stats ──
                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 200),
                  child: Text(
                    context.tr('Overview'),
                    style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
                  ),
                ),
                const SizedBox(height: 14),
                FadeInSlide(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 250),
                  child: _QuickStatsGrid(
                    availableLessons: snapshot?.availableLessons.length ?? 0,
                    activeCourses: enrolledGroups.length,
                    unreadCount: unreadCount,
                    balance: financialSummary?.remainingBalanceMinor ?? 0,
                    currency: financialSummary?.currency ?? 'EGP',
                    onLessons: () => onNavigate(1),
                    onCourses: () => onNavigate(1),
                    onNotifications: () => onNavigate(3),
                    onBilling: () => onNavigate(3),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Gamification ──
                if (gamification != null) ...[
                  FadeInSlide(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 300),
                    child: Text(
                      context.tr('Learning progress'),
                      style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 350),
                    child: _GamificationCard(summary: gamification),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Study Metrics ──
                if ((snapshot?.metrics ?? const []).isNotEmpty) ...[
                  FadeInSlide(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 350),
                    child: Text(
                      context.tr('Study Metrics'),
                      style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 400),
                    child: _StudyMetricsGrid(metrics: snapshot!.metrics),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Enrolled Groups preview ──
                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 400),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('Enrolled Groups'),
                          style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onNavigate(1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            context.tr('See all'),
                            style: AppTypography.labelLarge(AppColors.primary).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FadeInSlide(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 450),
                  child: SizedBox(
                    height: 340,
                    child: GroupListWidget(groups: enrolledGroups, isLoading: isLoading),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextLessonHero extends StatelessWidget {
  final bool isLoading;
  final StudyLessonSummary? lesson;
  final StudentGamificationSummary? gamification;
  final VoidCallback? onOpen;

  const _NextLessonHero({required this.isLoading, required this.lesson, required this.gamification, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlowContainer(
      glowColor: AppColors.primary,
      glowOpacity: isDark ? 0.35 : 0.15,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              HSLColor.fromColor(AppColors.primary).withLightness(math.max(0.0, HSLColor.fromColor(AppColors.primary).lightness - 0.12)).toColor(),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.2),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level badge
            if (gamification != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Level ${gamification!.level} · ${gamification!.streakDays}d streak',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            Text(
              isLoading ? context.tr('Loading…') : (lesson?.title ?? context.tr('No lesson available')),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.2),
            ),
            const SizedBox(height: 6),
            Text(
              isLoading
                  ? ''
                  : lesson == null
                      ? context.tr('Enroll in a group and wait for a published lesson.')
                      : '${lesson!.unitName}  ·  ${lesson!.estimatedMinutes} min',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
            ),
            if (!isLoading && lesson != null) ...[
              const SizedBox(height: 18),
              Stack(
                children: [
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                  ),
                  FractionallySizedBox(
                    widthFactor: lesson!.progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.4), blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${lesson!.progressPercentage}% ${context.tr("Completed Lessons")}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onOpen,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  onOpen == null ? context.tr('No lesson ready') : context.tr('Start Lesson'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatsGrid extends StatelessWidget {
  final int availableLessons;
  final int activeCourses;
  final int unreadCount;
  final int balance;
  final String currency;
  final VoidCallback onLessons;
  final VoidCallback onCourses;
  final VoidCallback onNotifications;
  final VoidCallback onBilling;

  const _QuickStatsGrid({
    required this.availableLessons,
    required this.activeCourses,
    required this.unreadCount,
    required this.balance,
    required this.currency,
    required this.onLessons,
    required this.onCourses,
    required this.onNotifications,
    required this.onBilling,
  });

  @override
  Widget build(BuildContext context) {
    return PortalMetricGrid(
      children: [
        PortalMetricCard(
          label: context.tr('Lessons'),
          value: '$availableLessons',
          icon: Icons.menu_book_rounded,
          accentColor: AppColors.studentRole,
          onTap: onLessons,
        ),
        PortalMetricCard(
          label: context.tr('Courses'),
          value: '$activeCourses',
          icon: Icons.grid_view_rounded,
          accentColor: AppColors.info,
          onTap: onCourses,
        ),
        PortalMetricCard(
          label: context.tr('Notifications'),
          value: '$unreadCount',
          icon: Icons.notifications_rounded,
          accentColor: AppColors.warning,
          onTap: onNotifications,
        ),
        PortalMetricCard(
          label: context.tr('Balance'),
          value: _formatMoney(balance, currency),
          icon: Icons.wallet_rounded,
          accentColor: AppColors.error,
          onTap: onBilling,
        ),
      ],
    );
  }
}

class _GamificationCard extends StatelessWidget {
  final StudentGamificationSummary summary;

  const _GamificationCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      color: surfaceColor,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Level circle
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${summary.level}',
                  style: AppTypography.titleLarge(AppColors.primary).copyWith(fontWeight: FontWeight.w900, fontSize: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${summary.totalXp} XP',
                      style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: (summary.levelProgressPercentage / 100).clamp(0.0, 1.0),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 6)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${summary.xpToNextLevel} XP ${context.tr("to next level")}',
                style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${summary.levelProgressPercentage.toInt()}%',
                style: AppTypography.caption(AppColors.primary).copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudyMetricsGrid extends StatelessWidget {
  final List<StudyMetric> metrics;

  const _StudyMetricsGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 560 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 110,
          ),
          itemBuilder: (context, i) {
            final m = metrics[i];
            return GlassCard(
              padding: const EdgeInsets.all(16),
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(textSecondary).copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(m.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5, fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(m.helper, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(textSecondary).copyWith(fontSize: 11)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
