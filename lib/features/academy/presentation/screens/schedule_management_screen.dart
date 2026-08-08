import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';

class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> {
  late final SupabaseScheduleRepository _scheduleRepo;
  late final SupabaseGroupRepository _groupRepo;
  List<ScheduleEntity> _schedules = [];
  List<GroupEntity> _groups = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _scheduleRepo = SupabaseScheduleRepository(wrapper);
    _groupRepo = SupabaseGroupRepository(wrapper);
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final g = await _groupRepo.fetchGroups();
      List<ScheduleEntity> s = [];
      if (g.isNotEmpty) {
        s = await _scheduleRepo.fetchSchedulesForGroup(g.first.id);
      }
      if (mounted) {
        setState(() {
          _groups = g;
          _schedules = s;
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

  void _showCreateScheduleDialog() {
    String? selectedGroupId = _groups.isNotEmpty ? _groups.first.id : null;
    int selectedDay = 1; // Monday
    TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 12, minute: 0);
    final roomCtrl = TextEditingController(text: 'Room 101');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Create Class Schedule'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_groups.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedGroupId,
                      decoration: const InputDecoration(
                        labelText: 'Select Group',
                      ),
                      items: _groups
                          .map(
                            (g) => DropdownMenuItem(
                              value: g.id,
                              child: Text(g.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => selectedGroupId = v),
                    ),
                  DropdownButtonFormField<int>(
                    initialValue: selectedDay,
                    decoration: const InputDecoration(labelText: 'Day of Week'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Monday')),
                      DropdownMenuItem(value: 2, child: Text('Tuesday')),
                      DropdownMenuItem(value: 3, child: Text('Wednesday')),
                      DropdownMenuItem(value: 4, child: Text('Thursday')),
                      DropdownMenuItem(value: 5, child: Text('Friday')),
                      DropdownMenuItem(value: 6, child: Text('Saturday')),
                      DropdownMenuItem(value: 7, child: Text('Sunday')),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => selectedDay = v);
                    },
                  ),
                  TextField(
                    controller: roomCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Room / Location',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedGroupId == null || roomCtrl.text.trim().isEmpty) {
                    return;
                  }

                  final nav = Navigator.of(ctx);
                  try {
                    final startStr =
                        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                    final endStr =
                        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

                    await _scheduleRepo.createSchedule(
                      groupId: selectedGroupId!,
                      dayOfWeek: selectedDay,
                      startTime: startStr,
                      endTime: endStr,
                      roomLocation: roomCtrl.text.trim(),
                    );
                    nav.pop();
                    _loadSchedules();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Class schedule created!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Schedule conflict: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Create Schedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedules,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateScheduleDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Schedule'),
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
                    onPressed: _loadSchedules,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _schedules.isEmpty
          ? const Center(child: Text('No class schedules found.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _schedules.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final s = _schedules[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.schedule)),
                  title: Text(
                    'Day ${s.dayOfWeek}: ${s.startTime} - ${s.endTime}',
                  ),
                  subtitle: Text('Location: ${s.roomLocation ?? "Main Hall"}'),
                );
              },
            ),
    );
  }
}
