import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/models/attendance_models.dart';

class TodaySessionsWidget extends StatelessWidget {
  final List<ClassSession> sessions;
  final bool isLoading;
  final ValueChanged<ClassSession>? onSessionSelected;

  const TodaySessionsWidget({
    super.key,
    required this.sessions,
    this.isLoading = false,
    this.onSessionSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.tr('No class sessions scheduled today.')),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final sess = sessions[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.event_note,
                  color: Colors.deepPurple,
                  size: 34,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.tr('Session')}: ${sess.sessionDate.toString().split(' ')[0]}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            '${context.tr('Location')}: ${sess.location ?? context.tr('Main Hall')}',
                          ),
                          Text(
                            '${context.tr('Status')}: ${context.tr(sess.status.name)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ElevatedButton(
                          onPressed: onSessionSelected != null
                              ? () => onSessionSelected!(sess)
                              : null,
                          child: Text(context.tr('Roll Call')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AttendanceRosterScreen extends StatefulWidget {
  final ClassSession session;
  final List<AttendanceRecord> initialRecords;
  final Function(List<Map<String, dynamic>> records)? onSave;
  final VoidCallback? onFinalize;

  const AttendanceRosterScreen({
    super.key,
    required this.session,
    this.initialRecords = const [],
    this.onSave,
    this.onFinalize,
  });

  @override
  State<AttendanceRosterScreen> createState() => _AttendanceRosterScreenState();
}

class _AttendanceRosterScreenState extends State<AttendanceRosterScreen> {
  final Map<String, AttendanceStatus> _statuses = {};

  @override
  void initState() {
    super.initState();
    for (final r in widget.initialRecords) {
      _statuses[r.studentId] = r.attendanceStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${context.tr('Roll Call')} - ${session.sessionDate.toString().split(' ')[0]}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: context.tr('Mark All Present'),
            onPressed: () {
              setState(() {
                for (final r in widget.initialRecords) {
                  _statuses[r.studentId] = AttendanceStatus.present;
                }
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              color: Colors.deepPurple.shade50,
              child: ListTile(
                leading: const Icon(Icons.class_, color: Colors.deepPurple),
                title: Text('${context.tr('Group Session')}: ${session.id}'),
                subtitle: Text(
                  '${context.tr('Status')}: ${context.tr(session.status.name)} | ${context.tr('Location')}: ${session.location ?? context.tr("N/A")}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: widget.initialRecords.length,
                itemBuilder: (context, index) {
                  final rec = widget.initialRecords[index];
                  final currentStatus =
                      _statuses[rec.studentId] ?? AttendanceStatus.present;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${context.tr('Student ID')}: ${rec.studentId.substring(0, 8)}...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${context.tr('Current')}: ${context.tr(currentStatus.name)}',
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<AttendanceStatus>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: AttendanceStatus.present,
                                  label: Text('P'),
                                ),
                                ButtonSegment(
                                  value: AttendanceStatus.late,
                                  label: Text('L'),
                                ),
                                ButtonSegment(
                                  value: AttendanceStatus.absent,
                                  label: Text('A'),
                                ),
                                ButtonSegment(
                                  value: AttendanceStatus.excused,
                                  label: Text('E'),
                                ),
                              ],
                              selected: {currentStatus},
                              onSelectionChanged: (val) {
                                setState(() {
                                  _statuses[rec.studentId] = val.first;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(context.tr('Save Roll Call')),
                  onPressed: () {
                    if (widget.onSave != null) {
                      final items = _statuses.entries
                          .map(
                            (e) => {
                              'student_id': e.key,
                              'attendance_status': e.value.toDbValue(),
                            },
                          )
                          .toList();
                      widget.onSave!(items);
                    }
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: Text(context.tr('Finalize Roll Call')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: widget.onFinalize,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceSummaryWidget extends StatelessWidget {
  final AttendanceSummary summary;

  const AttendanceSummaryWidget({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Attendance Summary'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (summary.attendancePercentage / 100.0).clamp(0.0, 1.0),
              backgroundColor: Colors.red.shade100,
              color: Colors.green,
              minHeight: 12,
            ),
            const SizedBox(height: 8),
            Text(
              '${context.tr('Rate')}: ${summary.attendancePercentage.toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceAround,
              children: [
                _buildStatBadge(
                  context,
                  'Present',
                  summary.presentCount,
                  Colors.green,
                ),
                _buildStatBadge(
                  context,
                  'Late',
                  summary.lateCount,
                  Colors.orange,
                ),
                _buildStatBadge(
                  context,
                  'Absent',
                  summary.absentCount,
                  Colors.red,
                ),
                _buildStatBadge(
                  context,
                  'Excused',
                  summary.excusedCount,
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(
    BuildContext context,
    String label,
    int count,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          context.tr(label),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
