import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
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
  late final SupabaseClassSessionRepository _sessionRepo;
  late final SupabaseAttendanceRepository _attendanceRepo;

  List<ClassSession> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _sessionRepo = SupabaseClassSessionRepository(wrapper);
    _attendanceRepo = SupabaseAttendanceRepository(wrapper);
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final s = await _sessionRepo.fetchSessionsForGroup(
        'c1000000-0000-0000-0000-000000000001',
      );
      if (mounted) {
        setState(() {
          _sessions = s;
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

  void _openRollCall(ClassSession session) {
    bool markAllPresent = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Roll Call: ${session.location ?? "Main Hall"}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('Mark All Enrolled Students Present'),
                value: markAllPresent,
                onChanged: (v) {
                  if (v != null) setStateDialog(() => markAllPresent = v);
                },
              ),
              const SizedBox(height: 8),
              const Card(
                color: Colors.lightBlueAccent,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Compensation Student: Assigned Make-Up Session',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                    records: [
                      {
                        'student_id': '90000000-0000-0000-0000-000000000001',
                        'status': markAllPresent ? 'present' : 'absent',
                      },
                    ],
                  );

                  await _attendanceRepo.finalizeSessionAttendance(session.id);
                  nav.pop();
                  _loadSessions();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Attendance finalized & persisted to backend!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Finalization error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Mark & Finalize Session'),
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSessions),
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
                    onPressed: _loadSessions,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _sessions.isEmpty
          ? const Center(
              child: Text('No active class sessions for attendance today.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _sessions.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final s = _sessions[i];
                final isFinalized = s.status == SessionStatus.completed;

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
                    'Session: ${s.location ?? "Main Hall"}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Date: ${s.sessionDate.year}-${s.sessionDate.month}-${s.sessionDate.day} | Status: ${s.status.name.toUpperCase()}',
                  ),
                  trailing: isFinalized
                      ? const Chip(
                          label: Text(
                            'FINALIZED',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          backgroundColor: Colors.green,
                        )
                      : ElevatedButton(
                          onPressed: () => _openRollCall(s),
                          child: const Text('Take Attendance'),
                        ),
                );
              },
            ),
    );
  }
}
