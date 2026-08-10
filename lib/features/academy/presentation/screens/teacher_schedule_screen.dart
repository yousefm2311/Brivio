import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';

class TeacherScheduleScreen extends StatefulWidget {
  final String teacherId;

  const TeacherScheduleScreen({super.key, required this.teacherId});

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseScheduleRepository _scheduleRepo;

  List<ScheduleEntity> _allSchedules = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _scheduleRepo = SupabaseScheduleRepository(wrapper);
    _loadTeacherSchedules();
  }

  Future<void> _loadTeacherSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      final List<ScheduleEntity> combined = [];

      for (final g in groups) {
        final schs = await _scheduleRepo.fetchSchedulesForGroup(g.id);
        combined.addAll(schs);
      }

      if (mounted) {
        setState(() {
          _allSchedules = combined;
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

  String _dayName(int day) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    if (day >= 1 && day <= 7) return days[day - 1];
    return 'Day $day';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtitleColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return RefreshIndicator(
      onRefresh: _loadTeacherSchedules,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: $_errorMessage',
                          style: AppTypography.bodyMedium(AppColors.error),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadTeacherSchedules,
                          child: Text('Retry', style: AppTypography.labelMedium(textColor)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : _allSchedules.isEmpty
          ? CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No recurring class schedules found for your assigned groups.',
                      style: AppTypography.bodyMedium(subtitleColor),
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _allSchedules.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final s = _allSchedules[i];
                return FadeInSlide(
                  delay: Duration(milliseconds: 50 * i),
                  child: GlassCard(
                    color: surfaceColor,
                    child: Row(
                      children: [
                        const CircleIcon(
                          icon: Icons.schedule,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _dayName(s.dayOfWeek),
                                style: AppTypography.titleMedium(textColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Time: ${s.startTime} - ${s.endTime} | Location: ${s.roomLocation ?? "Main Hall"}',
                                style: AppTypography.bodySmall(subtitleColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
