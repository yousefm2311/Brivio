import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_attendance_repositories.dart';
import '../../domain/models/attendance_models.dart';
import 'teacher_session_board_screen.dart';

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
    final messenger = ScaffoldMessenger.of(context);
    if (roster.isEmpty) {
      messenger.showSnackBar(
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
                            'attendance_status': entry.value.toDbValue(),
                          },
                        )
                        .toList(),
                  );
                  await _attendanceRepo.finalizeSessionAttendance(session.id);
                  nav.pop();
                  await _loadGroupsAndSessions();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Attendance finalized.')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
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

  void _openQrAttendance(ClassSession session) {
    showDialog(
      context: context,
      builder: (_) => _TeacherAttendanceQrDialog(session: session),
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
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Open session board',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TeacherSessionBoardScreen(
                        teacherId: widget.teacherId,
                        session: session,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.draw),
              ),
              if (!isFinalized)
                IconButton.filledTonal(
                  tooltip: 'Show rotating attendance QR',
                  onPressed: () => _openQrAttendance(session),
                  icon: const Icon(Icons.qr_code_2),
                ),
              if (isFinalized)
                const Chip(label: Text('FINALIZED'))
              else
                ElevatedButton(
                  onPressed: () => _openRollCall(session),
                  child: const Text('Take Attendance'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TeacherAttendanceQrDialog extends StatefulWidget {
  final ClassSession session;

  const _TeacherAttendanceQrDialog({required this.session});

  @override
  State<_TeacherAttendanceQrDialog> createState() =>
      _TeacherAttendanceQrDialogState();
}

class _TeacherAttendanceQrDialogState
    extends State<_TeacherAttendanceQrDialog> {
  Timer? _timer;
  bool _isLoading = true;
  String? _error;
  String? _token;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _loadQr();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _loadQr());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQr() async {
    if (!mounted) return;
    setState(() {
      _isLoading = _token == null;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'get_current_attendance_qr',
        params: {'p_class_session_id': widget.session.id},
      );
      final json = Map<String, dynamic>.from(response as Map);
      if (!mounted) return;
      setState(() {
        _token = json['token']?.toString();
        _expiresAt = DateTime.tryParse(json['expires_at']?.toString() ?? '');
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = _token;
    final qrPayload = token == null
        ? null
        : jsonEncode({'type': 'attendance_qr', 'token': token});
    final secondsLeft = _expiresAt
        ?.difference(DateTime.now())
        .inSeconds
        .clamp(0, 999);

    return AlertDialog(
      title: const Text('Attendance QR'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Students scan this QR to mark themselves present. It rotates every minute.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              )
            else if (qrPayload != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: qrPayload,
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              secondsLeft == null
                  ? 'Waiting for token'
                  : 'Expires in ${secondsLeft}s',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: _loadQr,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
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
