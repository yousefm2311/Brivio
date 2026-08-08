import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Teaching Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeacherSchedules,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: $_errorMessage',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadTeacherSchedules,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _allSchedules.isEmpty
          ? const Center(
              child: Text(
                'No recurring class schedules found for your assigned groups.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _allSchedules.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final s = _allSchedules[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.schedule)),
                  title: Text(
                    _dayName(s.dayOfWeek),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Time: ${s.startTime} - ${s.endTime} | Location: ${s.roomLocation ?? "Main Hall"}',
                  ),
                );
              },
            ),
    );
  }
}
