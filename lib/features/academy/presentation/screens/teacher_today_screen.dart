import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';

class TeacherTodayScreen extends StatefulWidget {
  final String teacherId;

  const TeacherTodayScreen({super.key, required this.teacherId});

  @override
  State<TeacherTodayScreen> createState() => _TeacherTodayScreenState();
}

class _TeacherTodayScreenState extends State<TeacherTodayScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseScheduleRepository _scheduleRepo;

  List<GroupEntity> _assignedGroups = [];
  List<ScheduleEntity> _todaySchedules = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _scheduleRepo = SupabaseScheduleRepository(wrapper);
    _loadTodaySchedule();
  }

  Future<void> _loadTodaySchedule() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      final todayWeekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun

      final List<ScheduleEntity> matchingSchedules = [];
      for (final g in groups) {
        final schs = await _scheduleRepo.fetchSchedulesForGroup(g.id);
        matchingSchedules.addAll(
          schs.where((s) => s.dayOfWeek == todayWeekday),
        );
      }

      if (mounted) {
        setState(() {
          _assignedGroups = groups;
          _todaySchedules = matchingSchedules;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Teaching Schedule"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodaySchedule,
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
                    onPressed: _loadTodaySchedule,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _todaySchedules.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.event_available,
                    size: 64,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No classes scheduled for today!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assigned Groups: ${_assignedGroups.length}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _todaySchedules.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final sch = _todaySchedules[i];
                final group = _assignedGroups.firstWhere(
                  (g) => g.id == sch.groupId,
                  orElse: () => GroupEntity(
                    id: sch.groupId,
                    code: 'GRP',
                    name: 'Assigned Group',
                    subjectId: '',
                    branchId: '',
                    status: 'active',
                  ),
                );

                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.alarm)),
                  title: Text(
                    group.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Time: ${sch.startTime} - ${sch.endTime} | Location: ${sch.roomLocation ?? "Main Hall"}',
                  ),
                  trailing: Chip(
                    label: const Text('UPCOMING'),
                    backgroundColor: Colors.blue.shade100,
                  ),
                );
              },
            ),
    );
  }
}
