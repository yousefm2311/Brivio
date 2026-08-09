import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
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
  late final SupabaseGroupRepository _groupRepo;
  late final SupabaseStudentRepository _studentRepo;

  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
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
    _groupRepo = SupabaseGroupRepository(wrapper);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _groupRepo.fetchGroups(status: 'active');
      final selected = _selectedGroup ?? (groups.isEmpty ? null : groups.first);
      final s = selected == null
          ? <ClassSession>[]
          : await _sessionRepo.fetchSessionsForGroup(selected.id);
      final rawLeaves = await Supabase.instance.client
          .from('leave_requests')
          .select()
          .order('submitted_at', ascending: false);
      final leaves = (rawLeaves as List)
          .map((j) => LeaveRequest.fromJson(j as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _groups = groups;
          _selectedGroup = selected;
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
    final statuses = <String, String>{};
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(
            'Session Roster (${session.sessionDate.year}-${session.sessionDate.month}-${session.sessionDate.day})',
          ),
          content: SizedBox(
            width: 420,
            child: FutureBuilder<List<Student>>(
              future: _studentRepo.fetchStudentsForGroup(session.groupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text('Failed to load roster: ${snapshot.error}');
                }
                final students = snapshot.data ?? [];
                if (students.isEmpty) {
                  return const Text('No enrolled students in this group.');
                }
                for (final student in students) {
                  statuses.putIfAbsent(student.id, () => 'present');
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: students
                      .map(
                        (student) => DropdownButtonFormField<String>(
                          initialValue: statuses[student.id],
                          decoration: InputDecoration(
                            labelText: student.fullName.isEmpty
                                ? student.studentCode
                                : student.fullName,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'present',
                              child: Text('Present'),
                            ),
                            DropdownMenuItem(
                              value: 'late',
                              child: Text('Late'),
                            ),
                            DropdownMenuItem(
                              value: 'absent',
                              child: Text('Absent'),
                            ),
                            DropdownMenuItem(
                              value: 'excused',
                              child: Text('Excused'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setStateDialog(() => statuses[student.id] = value);
                          },
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (statuses.isEmpty) return;
                final nav = Navigator.of(ctx);
                try {
                  await _attendanceRepo.markSessionAttendance(
                    sessionId: session.id,
                    records: statuses.entries
                        .map(
                          (entry) => {
                            'student_id': entry.key,
                            'status': entry.value,
                          },
                        )
                        .toList(),
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
              child: const Text('Save Attendance'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewLeaveDialog(LeaveRequest leave) {
    final noteCtrl = TextEditingController();

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
      child: PortalPageShell(
        title: 'Attendance & Operations',
        subtitle: 'Review sessions, mark rosters, and process leave requests.',
        icon: Icons.event_note,
        accentColor: AppColors.adminRole,
        actions: [
          PortalAction(
            icon: Icons.refresh,
            label: 'Refresh',
            onPressed: _loadData,
          ),
        ],
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.event_note), text: 'Sessions & Rosters'),
                Tab(icon: Icon(Icons.event_busy), text: 'Leave Requests'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PortalStateView(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: false,
                emptyTitle: 'No attendance data',
                emptySubtitle: 'Create groups and class sessions first.',
                emptyIcon: Icons.event_note,
                onRetry: _loadData,
                child: TabBarView(
                  children: [
                    Column(
                      children: [
                        if (_groups.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<GroupEntity>(
                              initialValue: _selectedGroup,
                              decoration: const InputDecoration(
                                labelText: 'Group',
                              ),
                              items: _groups
                                  .map(
                                    (g) => DropdownMenuItem(
                                      value: g,
                                      child: Text('${g.name} (${g.code})'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (group) {
                                if (group == null) return;
                                setState(() => _selectedGroup = group);
                                _loadData();
                              },
                            ),
                          ),
                        Expanded(
                          child: _selectedGroup == null
                              ? const Center(
                                  child: Text('No active groups found.'),
                                )
                              : _sessions.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No class sessions found for this group.',
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: _sessions.length,
                                  separatorBuilder: (ctx, i) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final s = _sessions[i];
                                    return PortalListCard(
                                      icon: Icons.event_note,
                                      accentColor: AppColors.adminRole,
                                      title:
                                          'Session: ${s.location ?? "No location assigned"}',
                                      subtitle:
                                          'Date: ${s.sessionDate.year}-${s.sessionDate.month}-${s.sessionDate.day} | Status: ${s.status.name.toUpperCase()}',
                                      trailing: [
                                        FilledButton(
                                          onPressed: () =>
                                              _openAttendanceRoster(s),
                                          child: const Text('Take Attendance'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                    _leaveRequests.isEmpty
                        ? const Center(
                            child: Text('No pending leave requests.'),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _leaveRequests.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final l = _leaveRequests[i];
                              return PortalListCard(
                                icon: Icons.event_busy,
                                accentColor: l.status == 'pending'
                                    ? AppColors.warning
                                    : AppColors.info,
                                title:
                                    'Leave Request (${l.status.toUpperCase()})',
                                subtitle: 'Reason: ${l.reason}',
                                trailing: [
                                  if (l.status == 'pending')
                                    FilledButton(
                                      onPressed: () =>
                                          _showReviewLeaveDialog(l),
                                      child: const Text('Review'),
                                    )
                                  else
                                    PortalStatusChip(status: l.status),
                                ],
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
