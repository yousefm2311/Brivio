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

  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<ScheduleEntity> _schedules = [];
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
      GroupEntity? selected = _selectedGroup;
      if (selected == null && groups.isNotEmpty) {
        selected = groups.first;
      } else if (selected != null) {
        selected = groups.where((g) => g.id == selected!.id).firstOrNull;
      }

      final schedules = selected == null
          ? <ScheduleEntity>[]
          : await _scheduleRepo.fetchSchedulesForGroup(selected.id);

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _schedules = schedules;
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
    await _loadTeacherSchedules();
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

  String _timeString(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  TimeOfDay _parseTime(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length < 2) return fallback;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? fallback.hour,
      minute: int.tryParse(parts[1]) ?? fallback.minute,
    );
  }

  void _showScheduleDialog({ScheduleEntity? schedule}) {
    final group = _selectedGroup;
    if (group == null) return;

    final isEditing = schedule != null;
    int selectedDay = schedule?.dayOfWeek ?? 1;
    TimeOfDay startTime = schedule == null
        ? const TimeOfDay(hour: 10, minute: 0)
        : _parseTime(schedule.startTime, const TimeOfDay(hour: 10, minute: 0));
    TimeOfDay endTime = schedule == null
        ? const TimeOfDay(hour: 12, minute: 0)
        : _parseTime(schedule.endTime, const TimeOfDay(hour: 12, minute: 0));
    final roomCtrl = TextEditingController(text: schedule?.roomLocation ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Schedule' : 'Create Schedule'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedDay,
                  decoration: const InputDecoration(labelText: 'Day'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Monday')),
                    DropdownMenuItem(value: 2, child: Text('Tuesday')),
                    DropdownMenuItem(value: 3, child: Text('Wednesday')),
                    DropdownMenuItem(value: 4, child: Text('Thursday')),
                    DropdownMenuItem(value: 5, child: Text('Friday')),
                    DropdownMenuItem(value: 6, child: Text('Saturday')),
                    DropdownMenuItem(value: 7, child: Text('Sunday')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedDay = value);
                    }
                  },
                ),
                TextField(
                  controller: roomCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Room / Location',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.schedule),
                        label: Text('Start ${startTime.format(context)}'),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: startTime,
                          );
                          if (picked != null) {
                            setDialogState(() => startTime = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.schedule),
                        label: Text('End ${endTime.format(context)}'),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: endTime,
                          );
                          if (picked != null) {
                            setDialogState(() => endTime = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: Icon(isEditing ? Icons.save : Icons.add),
              label: Text(isEditing ? 'Save' : 'Create'),
              onPressed: () async {
                final nav = Navigator.of(ctx);
                try {
                  if (isEditing) {
                    await _scheduleRepo.updateSchedule(
                      scheduleId: schedule.id,
                      dayOfWeek: selectedDay,
                      startTime: _timeString(startTime),
                      endTime: _timeString(endTime),
                      roomLocation: roomCtrl.text.trim(),
                    );
                  } else {
                    await _scheduleRepo.createSchedule(
                      groupId: group.id,
                      dayOfWeek: selectedDay,
                      startTime: _timeString(startTime),
                      endTime: _timeString(endTime),
                      roomLocation: roomCtrl.text.trim(),
                    );
                  }
                  nav.pop();
                  await _loadTeacherSchedules();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Schedule save failed: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSchedule(ScheduleEntity schedule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Delete this recurring class time?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _scheduleRepo.deleteSchedule(schedule.id);
      await _loadTeacherSchedules();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Schedule delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final subtitleColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedGroup == null ? null : () => _showScheduleDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Schedule'),
      ),
      body: RefreshIndicator(
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
                            child: Text(
                              'Retry',
                              style: AppTypography.labelMedium(textColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: DropdownButtonFormField<GroupEntity>(
                      initialValue: _selectedGroup,
                      decoration: const InputDecoration(
                        labelText: 'Group',
                        border: OutlineInputBorder(),
                      ),
                      items: _groups
                          .map(
                            (group) => DropdownMenuItem(
                              value: group,
                              child: Text(group.name),
                            ),
                          )
                          .toList(),
                      onChanged: _groups.isEmpty ? null : _selectGroup,
                    ),
                  ),
                  Expanded(
                    child: _schedules.isEmpty
                        ? Center(
                            child: Text(
                              'No recurring class schedules found for this group.',
                              style: AppTypography.bodyMedium(subtitleColor),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _schedules.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 12),
                            itemBuilder: (ctx, i) {
                              final schedule = _schedules[i];
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _dayName(schedule.dayOfWeek),
                                              style: AppTypography.titleMedium(
                                                textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Time: ${schedule.startTime} - ${schedule.endTime} | Location: ${schedule.roomLocation ?? "Main Hall"}',
                                              style: AppTypography.bodySmall(
                                                subtitleColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _showScheduleDialog(
                                          schedule: schedule,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: AppColors.error,
                                        ),
                                        onPressed: () =>
                                            _deleteSchedule(schedule),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
