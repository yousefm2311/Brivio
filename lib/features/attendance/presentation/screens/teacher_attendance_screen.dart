import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_attendance_repositories.dart';
import '../../domain/models/attendance_models.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  final String teacherId;

  const TeacherAttendanceScreen({super.key, required this.teacherId});

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseStudentRepository _studentRepo;
  late final SupabaseClassSessionRepository _sessionRepo;
  late final SupabaseAttendanceRepository _attendanceRepo;

  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<ClassSession> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _sessionRepo = SupabaseClassSessionRepository(wrapper);
    _attendanceRepo = SupabaseAttendanceRepository(wrapper);
    _loadGroupsAndSessions();
  }

  Future<void> _loadGroupsAndSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      GroupEntity? selected;
      if (_selectedGroup == null) {
        selected = groups.isNotEmpty ? groups.first : null;
      } else {
        for (final group in groups) {
          if (group.id == _selectedGroup!.id) {
            selected = group;
            break;
          }
        }
      }
      final sessions = selected == null
          ? <ClassSession>[]
          : await _sessionRepo.fetchSessionsForGroup(selected.id);

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _sessions = sessions;
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
    await _loadGroupsAndSessions();
  }

  Future<void> _openRollCall(ClassSession session) async {
    final roster = await _studentRepo.fetchStudentsForGroup(session.groupId);
    if (!mounted) return;
    if (roster.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No enrolled students in this group.')),
      );
      return;
    }

    final statuses = {
      for (final student in roster) student.id: AttendanceStatus.present,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Roll Call: ${session.location ?? "Session"}'),
          content: SizedBox(
            width: 520,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: roster.length,
              itemBuilder: (context, index) {
                final student = roster[index];
                return DropdownButtonFormField<AttendanceStatus>(
                  initialValue: statuses[student.id],
                  decoration: InputDecoration(labelText: student.fullName),
                  items: AttendanceStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setStateDialog(() => statuses[student.id] = value);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                try {
                  await _attendanceRepo.markSessionAttendance(
                    sessionId: session.id,
                    records: statuses.entries
                        .map(
                          (entry) => {
                            'student_id': entry.key,
                            'status': entry.value.toDbValue(),
                          },
                        )
                        .toList(),
                  );
                  await _attendanceRepo.finalizeSessionAttendance(session.id);
                  nav.pop();
                  await _loadGroupsAndSessions();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Attendance finalized.')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Finalization error: $e')),
                  );
                }
              },
              child: const Text('Finalize'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Daily Attendance Workspace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroupsAndSessions,
          ),
        ],
      ),
      body: Column(
        children: [
          _GroupPicker(
            groups: _groups,
            selectedGroup: _selectedGroup,
            onChanged: _selectGroup,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return _ErrorState(
        message: _errorMessage!,
        onRetry: _loadGroupsAndSessions,
      );
    }
    if (_selectedGroup == null) {
      return const Center(child: Text('No assigned groups found.'));
    }
    if (_sessions.isEmpty) {
      return const Center(
        child: Text('No active class sessions for this group.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      separatorBuilder: (ctx, i) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final session = _sessions[i];
        final isFinalized = session.status == SessionStatus.completed;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isFinalized
                ? Colors.green.shade100
                : Colors.orange.shade100,
            child: Icon(
              Icons.event_available,
              color: isFinalized ? Colors.green : Colors.orange,
            ),
          ),
          title: Text(
            'Session: ${session.location ?? "Main Hall"}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Date: ${session.sessionDate.year}-${session.sessionDate.month}-${session.sessionDate.day} | Status: ${session.status.name.toUpperCase()}',
          ),
          trailing: isFinalized
              ? const Chip(label: Text('FINALIZED'))
              : ElevatedButton(
                  onPressed: () => _openRollCall(session),
                  child: const Text('Take Attendance'),
                ),
        );
      },
    );
  }
}

class _GroupPicker extends StatelessWidget {
  final List<GroupEntity> groups;
  final GroupEntity? selectedGroup;
  final ValueChanged<GroupEntity?> onChanged;

  const _GroupPicker({
    required this.groups,
    required this.selectedGroup,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<GroupEntity>(
        initialValue: selectedGroup,
        decoration: const InputDecoration(
          labelText: 'Assigned group',
          border: OutlineInputBorder(),
        ),
        items: groups
            .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
            .toList(),
        onChanged: groups.isEmpty ? null : onChanged,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
