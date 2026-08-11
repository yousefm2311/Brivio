import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_attendance_repositories.dart';
import '../../domain/models/attendance_models.dart';
import 'teacher_session_board_screen.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/components/glass_card.dart';

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
        SnackBar(
          content: Text(context.tr('No enrolled students in this group.')),
        ),
      );
      return;
    }

    final statuses = {
      for (final student in roster) student.id: AttendanceStatus.present,
    };

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (stateCtx, setStateDialog) => AlertDialog(
          title: Text(
            '${context.tr('Roll Call')}: ${session.location ?? context.tr('Session')}',
          ),
          content: SizedBox(
            width: 520,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: roster.length,
              itemBuilder: (listCtx, index) {
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
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(context.tr('Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final nav = Navigator.of(dialogCtx);
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
                    SnackBar(
                      content: Text(context.tr('Attendance finalized.')),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('${context.tr('Finalization error')}: $e'),
                    ),
                  );
                }
              },
              child: Text(context.tr('Finalize')),
            ),
          ],
        ),
      ),
    );
  }

  void _openQrAttendance(ClassSession session) {
    showDialog(
      context: context,
      builder: (_) => _TeacherAttendanceQrDialog(
        session: session,
        onFinalized: _loadGroupsAndSessions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GroupPicker(
          groups: _groups,
          selectedGroup: _selectedGroup,
          onChanged: _selectGroup,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadGroupsAndSessions,
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          _ErrorState(message: _errorMessage!, onRetry: _loadGroupsAndSessions),
        ],
      );
    }
    if (_selectedGroup == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(child: Text(context.tr('No assigned groups found.'), style: AppTypography.bodyMedium(AppColors.darkTextSecondary))),
        ],
      );
    }
    if (_sessions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(child: Text(context.tr('No active class sessions for this group.'), style: AppTypography.bodyMedium(AppColors.darkTextSecondary))),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length + 1,
      itemBuilder: (ctx, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FilledButton.icon(
              onPressed: _showCreateSessionDialog,
              icon: const Icon(Icons.add),
              label: Text(context.tr('Create New Session')),
            ),
          );
        }
        
        final i = index - 1;
        final session = _sessions[i];
        final isFinalized = session.status == SessionStatus.completed;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FadeInSlide(
          delay: Duration(milliseconds: 30 * i),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isFinalized ? AppColors.successSubtle : AppColors.warningSubtle,
                  child: Icon(
                    Icons.event_available,
                    color: isFinalized ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.tr('Session')}: ${session.location ?? context.tr('Main Hall')}',
                        style: AppTypography.titleMedium(AppColors.darkTextPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${context.tr('Date')}: ${session.sessionDate.year}-${session.sessionDate.month}-${session.sessionDate.day} | ${context.tr('Status')}: ${context.tr(session.status.name)}',
                        style: AppTypography.bodySmall(AppColors.darkTextSecondary),
                      ),
                    ],
                  ),
                ),
                Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
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
                    icon: const Icon(Icons.draw, size: 18),
                    label: Text(context.tr('Whiteboard')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (!isFinalized)
                    IconButton.filledTonal(
                      tooltip: context.tr('Show rotating attendance QR'),
                      onPressed: () => _openQrAttendance(session),
                      icon: const Icon(Icons.qr_code_2),
                    ),
                  if (isFinalized)
                    StatusChip(label: context.tr('FINALIZED'), status: ChipStatus.success)
                  else
                    ElevatedButton(
                      onPressed: () => _openRollCall(session),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(context.tr('Take Attendance')),
                    ),
                ],
              ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
  Future<void> _showCreateSessionDialog() async {
    if (_selectedGroup == null) return;
    
    final locationController = TextEditingController();
    DateTime? selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (stateCtx, setState) {
          return AlertDialog(
            title: Text(context.tr('Create Session')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: context.tr('Location / Room'),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('Date')),
                  subtitle: Text('${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: stateCtx,
                      initialDate: selectedDate!,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.tr('Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.tr('Create')),
              ),
            ],
          );
        }
      ),
    );

    if (result == true) {
      try {
        await _sessionRepo.createClassSession(ClassSession(
          id: '', // Will be generated by DB
          groupId: _selectedGroup!.id,
          sessionDate: selectedDate!,
          scheduledStartAt: selectedDate!,
          scheduledEndAt: selectedDate!.add(const Duration(hours: 1)),
          status: SessionStatus.scheduled,
          location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
        ));
        await _loadGroupsAndSessions();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create session: $e')));
      }
    }
  }
}

class _TeacherAttendanceQrDialog extends StatefulWidget {
  final ClassSession session;
  final Future<void> Function()? onFinalized;

  const _TeacherAttendanceQrDialog({required this.session, this.onFinalized});

  @override
  State<_TeacherAttendanceQrDialog> createState() =>
      _TeacherAttendanceQrDialogState();
}

class _TeacherAttendanceQrDialogState
    extends State<_TeacherAttendanceQrDialog> {
  Timer? _timer;
  bool _isLoading = true;
  bool _isFinalizing = false;
  String? _error;
  String? _token;
  DateTime? _expiresAt;
  List<_QrRosterItem> _roster = [];

  @override
  void initState() {
    super.initState();
    _refreshQrWorkspace();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshQrWorkspace(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshQrWorkspace() async {
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
      final rosterResponse = await Supabase.instance.client.rpc(
        'get_session_qr_attendance_roster',
        params: {'p_class_session_id': widget.session.id},
      );
      final json = Map<String, dynamic>.from(response as Map);
      final roster = (rosterResponse as List)
          .whereType<Map>()
          .map((row) => _QrRosterItem.fromMap(row))
          .toList();
      if (!mounted) return;
      setState(() {
        _token = json['token']?.toString();
        _expiresAt = DateTime.tryParse(json['expires_at']?.toString() ?? '');
        _roster = roster;
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

  Future<void> _finalizeAttendance() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Finalize QR attendance?')),
        content: Text(
          context.tr(
            'Students who did not scan the QR will be marked absent and this session will be completed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('Finalize')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isFinalizing = true);
    try {
      final response = await Supabase.instance.client.rpc(
        'finalize_qr_attendance',
        params: {'p_class_session_id': widget.session.id},
      );
      final json = Map<String, dynamic>.from(response as Map);
      _timer?.cancel();
      await widget.onFinalized?.call();
      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${context.tr('Attendance finalized')}: ${json['present_count'] ?? 0} ${context.tr('present')}, '
            '${json['late_count'] ?? 0} ${context.tr('late')}, ${json['absent_count'] ?? 0} ${context.tr('absent')}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFinalizing = false);
      messenger.showSnackBar(
        SnackBar(content: Text('${context.tr('Finalization failed')}: $e')),
      );
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
    final presentCount = _roster
        .where((item) => item.status == 'present' || item.status == 'late')
        .length;

    return AlertDialog(
      title: Text(context.tr('Attendance QR')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
              context.tr(
                'Students scan this QR to mark themselves present. It rotates every minute.',
              ),
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
                  ? context.tr('Waiting for token')
                  : '${context.tr('Expires in')} ${secondsLeft}s',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${context.tr('Present')}: $presentCount',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.green),
                ),
                Text(
                  '${context.tr('Absent')}: ${_roster.length - presentCount}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.red),
                ),
                Text(
                  '${context.tr('Total')}: ${_roster.length}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: _roster.isEmpty
                  ? Center(child: Text(context.tr('Roster will appear here.')))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _roster.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _roster[index];
                        final checkedIn =
                            item.status == 'present' || item.status == 'late';
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            checkedIn
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: checkedIn ? Colors.green : Colors.grey,
                          ),
                          title: Text(item.fullName),
                          subtitle: Text(
                            item.checkInAt == null
                                ? item.studentCode
                                : '${item.studentCode} | ${_formatQrTime(item.checkInAt!)} | ${item.markedByQr ? "QR" : context.tr("Manual")}',
                          ),
                          trailing: Text(context.tr(item.status)),
                        );
                      },
                    ),
            ),
          ],
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isFinalizing ? null : () => Navigator.pop(context),
          child: Text(context.tr('Close')),
        ),
        OutlinedButton.icon(
          onPressed: _isFinalizing ? null : _finalizeAttendance,
          icon: _isFinalizing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.done_all),
          label: Text(context.tr('Finalize Attendance')),
        ),
        FilledButton.icon(
          onPressed: _isFinalizing ? null : _refreshQrWorkspace,
          icon: const Icon(Icons.refresh),
          label: Text(context.tr('Refresh')),
        ),
      ],
    );
  }
}

class _QrRosterItem {
  final String studentId;
  final String studentCode;
  final String fullName;
  final String status;
  final DateTime? checkInAt;
  final String? deviceId;
  final bool markedByQr;

  const _QrRosterItem({
    required this.studentId,
    required this.studentCode,
    required this.fullName,
    required this.status,
    required this.checkInAt,
    required this.deviceId,
    required this.markedByQr,
  });

  factory _QrRosterItem.fromMap(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _QrRosterItem(
      studentId: json['student_id']?.toString() ?? '',
      studentCode: json['student_code']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Student',
      status: json['attendance_status']?.toString() ?? 'pending',
      checkInAt: DateTime.tryParse(json['check_in_at']?.toString() ?? ''),
      deviceId: json['device_id']?.toString(),
      markedByQr: json['marked_by_qr'] == true,
    );
  }
}

String _formatQrTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
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
        decoration: InputDecoration(
          labelText: context.tr('Assigned group'),
          border: const OutlineInputBorder(),
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
            ElevatedButton(
              onPressed: onRetry,
              child: Text(context.tr('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
