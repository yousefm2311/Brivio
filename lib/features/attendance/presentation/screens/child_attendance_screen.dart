import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../viewmodels/child_attendance_viewmodel.dart';

class ChildAttendanceScreen extends StatelessWidget {
  const ChildAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChildAttendanceViewModel(),
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: const _ChildAttendanceBody(),
      ),
    );
  }
}

class _ChildAttendanceBody extends StatelessWidget {
  const _ChildAttendanceBody();

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChildAttendanceViewModel>();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.darkBackground,
          pinned: true,
          title: const Text(
            'Attendance & Behavior',
            style: TextStyle(
              color: AppColors.darkTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
        ),
        if (viewModel.isLoading)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatsCards(viewModel),
                const SizedBox(height: 32),
                const SectionHeader(title: 'Recent Attendance Issues'),
                _buildAttendanceList(viewModel.attendanceRecords),
                const SizedBox(height: 32),
                const SectionHeader(title: 'Behavior Records'),
                _buildBehaviorList(viewModel.behaviorRecords),
                const SizedBox(height: 40),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsCards(ChildAttendanceViewModel viewModel) {
    return Row(
      children: [
        Expanded(
          child: GlowContainer(
            glowColor: AppColors.error,
            glowOpacity: 0.15,
            padding: EdgeInsets.zero,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  const Icon(
                    Icons.event_busy,
                    color: AppColors.error,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${viewModel.totalAbsences}',
                    style: const TextStyle(
                      color: AppColors.darkTextPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Absences',
                    style: TextStyle(
                      color: AppColors.darkTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GlowContainer(
            glowColor: AppColors.warning,
            glowOpacity: 0.15,
            padding: EdgeInsets.zero,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  const Icon(
                    Icons.watch_later_outlined,
                    color: AppColors.warning,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${viewModel.totalTardiness}',
                    style: const TextStyle(
                      color: AppColors.darkTextPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tardiness',
                    style: TextStyle(
                      color: AppColors.darkTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceList(List<AttendanceRecord> records) {
    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No attendance issues recorded.',
          style: TextStyle(color: AppColors.darkTextSecondary),
        ),
      );
    }
    return Column(
      children: records.map((r) {
        final isAbsent = r.status == 'absent';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FadeInSlide(
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleIcon(
                    icon: isAbsent ? Icons.cancel_outlined : Icons.schedule,
                    color: isAbsent ? AppColors.error : AppColors.warning,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAbsent ? 'Absent' : 'Late',
                          style: const TextStyle(
                            color: AppColors.darkTextPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (r.note != null)
                          Text(
                            r.note!,
                            style: const TextStyle(
                              color: AppColors.darkTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDate(r.date),
                    style: const TextStyle(
                      color: AppColors.darkTextTertiary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBehaviorList(List<BehaviorRecord> records) {
    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No behavior records.',
          style: TextStyle(color: AppColors.darkTextSecondary),
        ),
      );
    }
    return Column(
      children: records.map((r) {
        final isPositive = r.type == 'positive';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FadeInSlide(
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isPositive
                        ? Icons.thumb_up_alt_outlined
                        : Icons.warning_amber_rounded,
                    color: isPositive ? AppColors.success : AppColors.warning,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isPositive ? 'Positive Behavior' : 'Incident',
                              style: TextStyle(
                                color: isPositive
                                    ? AppColors.success
                                    : AppColors.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _formatDate(r.date),
                              style: const TextStyle(
                                color: AppColors.darkTextTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          r.description,
                          style: const TextStyle(
                            color: AppColors.darkTextPrimary,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: AppColors.darkTextTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reported by ${r.teacher}',
                              style: const TextStyle(
                                color: AppColors.darkTextTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
