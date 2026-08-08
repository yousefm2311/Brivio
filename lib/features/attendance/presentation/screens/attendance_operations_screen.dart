import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../data/repositories/supabase_attendance_repositories.dart';
import '../../domain/models/attendance_models.dart';

class AttendanceOperationsScreen extends StatefulWidget {
  const AttendanceOperationsScreen({super.key});

  @override
  State<AttendanceOperationsScreen> createState() =>
      _AttendanceOperationsScreenState();
}

class _AttendanceOperationsScreenState
    extends State<AttendanceOperationsScreen> {
  late final SupabaseClassSessionRepository _sessionRepo;
  late final SupabaseAttendanceRepository _attendanceRepo;
  late final SupabaseLeaveRepository _leaveRepo;

  List<ClassSession> _sessions = [];
  List<LeaveRequest> _leaveRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _sessionRepo = SupabaseClassSessionRepository(wrapper);
    _attendanceRepo = SupabaseAttendanceRepository(wrapper);
    _leaveRepo = SupabaseLeaveRepository(wrapper);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final s = await _sessionRepo.fetchSessionsForGroup(
        'c1000000-0000-0000-0000-000000000001',
      );
      final leaves = await _leaveRepo.fetchLeaveRequestsForStudent(
        '90000000-0000-0000-0000-000000000001',
      );
      if (mounted) {
        setState(() {
          _sessions = s;
          _leaveRequests = leaves;
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

  void _openAttendanceRoster(ClassSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Session Roster (${session.sessionDate.year}-${session.sessionDate.month}-${session.sessionDate.day})',
        ),
        content: const Text('Mark Student Attendance for active session.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
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
                      'status': 'present',
                    },
                  ],
                );
                nav.pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Attendance recorded & finalized!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Recording failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Mark Present & Finalize'),
          ),
        ],
      ),
    );
  }

  void _showReviewLeaveDialog(LeaveRequest leave) {
    final noteCtrl = TextEditingController(text: 'Approved by Branch Admin');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review Leave Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reason: ${leave.reason}'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Reviewer Note'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await _leaveRepo.reviewLeaveRequest(
                  requestId: leave.id,
                  decision: 'rejected',
                  reviewerNote: noteCtrl.text.trim(),
                );
                nav.pop();
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Leave request rejected.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Review failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await _leaveRepo.reviewLeaveRequest(
                  requestId: leave.id,
                  decision: 'approved',
                  reviewerNote: noteCtrl.text.trim(),
                );
                nav.pop();
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Leave request approved!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Review failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance & Operations'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.event_note), text: 'Sessions & Rosters'),
              Tab(icon: Icon(Icons.event_busy), text: 'Leave Requests'),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
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
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : TabBarView(
                children: [
                  // Tab 1: Sessions
                  _sessions.isEmpty
                      ? const Center(
                          child: Text('No class sessions found for today.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _sessions.length,
                          separatorBuilder: (ctx, i) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final s = _sessions[i];
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.event_note),
                              ),
                              title: Text(
                                'Session: ${s.location ?? "Main Hall"}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Date: ${s.sessionDate.year}-${s.sessionDate.month}-${s.sessionDate.day} | Status: ${s.status.name.toUpperCase()}',
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => _openAttendanceRoster(s),
                                child: const Text('Take Attendance'),
                              ),
                            );
                          },
                        ),
                  // Tab 2: Leave Requests
                  _leaveRequests.isEmpty
                      ? const Center(child: Text('No pending leave requests.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _leaveRequests.length,
                          separatorBuilder: (ctx, i) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final l = _leaveRequests[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: l.status == 'pending'
                                    ? Colors.orange.shade100
                                    : Colors.blue.shade100,
                                child: Icon(
                                  Icons.event_busy,
                                  color: l.status == 'pending'
                                      ? Colors.orange
                                      : Colors.blue,
                                ),
                              ),
                              title: Text(
                                'Leave Request (${l.status.toUpperCase()})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text('Reason: ${l.reason}'),
                              trailing: l.status == 'pending'
                                  ? ElevatedButton(
                                      onPressed: () =>
                                          _showReviewLeaveDialog(l),
                                      child: const Text('Review'),
                                    )
                                  : Chip(label: Text(l.status.toUpperCase())),
                            );
                          },
                        ),
                ],
              ),
      ),
    );
  }
}
