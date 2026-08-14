import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';
import '../../../assessment/data/repositories/supabase_assessment_repositories.dart';
import '../../../assessment/domain/models/assessment_models.dart';
import '../../../attendance/data/repositories/supabase_attendance_repositories.dart';
import '../../../attendance/domain/models/attendance_models.dart';
import '../../../../core/services/report_generator_service.dart';

class TeacherGroupDetailsScreen extends StatefulWidget {
  final GroupEntity group;

  const TeacherGroupDetailsScreen({super.key, required this.group});

  @override
  State<TeacherGroupDetailsScreen> createState() =>
      _TeacherGroupDetailsScreenState();
}

class _TeacherGroupDetailsScreenState extends State<TeacherGroupDetailsScreen> {
  late final SupabaseStudentRepository _studentRepo;
  late final SupabaseHomeworkRepository _homeworkRepo;
  late final SupabaseClassSessionRepository _sessionRepo;

  List<Student> _enrolledStudents = [];
  List<Homework> _groupHomeworks = [];
  List<ClassSession> _groupSessions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _homeworkRepo = SupabaseHomeworkRepository(wrapper);
    _sessionRepo = SupabaseClassSessionRepository(wrapper);
    _loadGroupDetails();
  }

  Future<void> _loadGroupDetails() async {
    setState(() => _isLoading = true);
    try {
      final sRes = await _studentRepo.fetchStudentsForGroup(widget.group.id);
      final hwRes = await _homeworkRepo.fetchHomeworkForGroup(widget.group.id);
      final sessRes = await _sessionRepo.fetchSessionsForGroup(widget.group.id);

      if (mounted) {
        setState(() {
          _enrolledStudents = sRes;
          _groupHomeworks = hwRes;
          _groupSessions = sessRes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportGradesReport() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gathering grades data...')),
        );
      }
      final service = ReportGeneratorService();

      final studentIds = _enrolledStudents.map((s) => s.id).toList();

      List<dynamic> examAttempts = [];
      List<dynamic> hwSubmissions = [];
      if (studentIds.isNotEmpty) {
        examAttempts = await Supabase.instance.client
            .from('exam_attempts')
            .select('student_id, score')
            .filter('student_id', 'in', studentIds);

        hwSubmissions = await Supabase.instance.client
            .from('homework_submissions')
            .select('student_id, score')
            .filter('student_id', 'in', studentIds);
      }

      final data = _enrolledStudents.map((s) {
        final sExams = examAttempts
            .where((e) => e['student_id'] == s.id)
            .toList();
        final sHws = hwSubmissions
            .where((h) => h['student_id'] == s.id)
            .toList();

        final examAvg = sExams.isEmpty
            ? 0
            : sExams.map((e) => e['score'] as num).reduce((a, b) => a + b) /
                  sExams.length;
        final hwAvg = sHws.isEmpty
            ? 0
            : sHws.map((h) => h['score'] as num).reduce((a, b) => a + b) /
                  sHws.length;

        return {
          'name': s.fullName,
          'exam_score': examAvg.toStringAsFixed(1),
          'homework_score': hwAvg.toStringAsFixed(1),
          'missing_assignments': _groupHomeworks.length - sHws.length > 0
              ? _groupHomeworks.length - sHws.length
              : 0,
        };
      }).toList();

      await service.generateGradesReport(
        className: widget.group.name,
        studentsData: data,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grades report generated & saved.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportAttendanceReport() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gathering attendance data...')),
        );
      }
      final service = ReportGeneratorService();

      final studentIds = _enrolledStudents.map((s) => s.id).toList();
      List<dynamic> attendance = [];
      if (studentIds.isNotEmpty) {
        attendance = await Supabase.instance.client
            .from('attendance')
            .select('student_id, date, status')
            .filter('student_id', 'in', studentIds);
      }

      final data = _enrolledStudents.map((s) {
        final sAtt = attendance.where((a) => a['student_id'] == s.id).toList();
        final presentCount = sAtt.where((a) => a['status'] == 'present').length;
        final absentCount = sAtt.where((a) => a['status'] == 'absent').length;
        final absentDates = sAtt
            .where((a) => a['status'] == 'absent')
            .map((a) => a['date'])
            .join(', ');

        return {
          'name': s.fullName,
          'present': presentCount,
          'absent': absentCount,
          'absence_dates': absentDates.isEmpty ? 'None' : absentDates,
        };
      }).toList();

      await service.generateAttendanceReport(
        className: widget.group.name,
        attendanceData: data,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance report generated & saved.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Group: ${widget.group.name}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete Group',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Group'),
                    content: const Text(
                      'Are you sure you want to delete this group?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await Supabase.instance.client.rpc(
                      'delete_group',
                      params: {'group_id': widget.group.id},
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Group deleted')),
                      );
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.info), text: 'Overview'),
              Tab(icon: Icon(Icons.people), text: 'Students'),
              Tab(icon: Icon(Icons.assignment), text: 'Homework'),
              Tab(icon: Icon(Icons.quiz), text: 'Exams'),
              Tab(icon: Icon(Icons.event_note), text: 'Attendance'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Tab 1: Overview
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Group Name: ${widget.group.name}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Group Code: ${widget.group.code}'),
                            Text(
                              'Max Capacity: ${widget.group.maxCapacity ?? "Unlimited"}',
                            ),
                            Text(
                              'Enrolled Students: ${_enrolledStudents.length}',
                            ),
                            Text(
                              'Status: ${widget.group.status.toUpperCase()}',
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _exportGradesReport,
                              icon: const Icon(Icons.download),
                              label: const Text('Export Grades Report'),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _exportAttendanceReport,
                              icon: const Icon(Icons.download),
                              label: const Text('Export Attendance Report'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Tab 2: Students Roster
                  _enrolledStudents.isEmpty
                      ? const Center(
                          child: Text('No enrolled students in this group.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _enrolledStudents.length,
                          separatorBuilder: (ctx, i) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final s = _enrolledStudents[i];
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.school),
                              ),
                              title: Text(
                                s.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Code: ${s.studentCode} | Email: ${s.email}',
                              ),
                            );
                          },
                        ),
                  // Tab 3: Homework
                  _groupHomeworks.isEmpty
                      ? const Center(
                          child: Text(
                            'No homework assignments published for this group.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _groupHomeworks.length,
                          separatorBuilder: (ctx, i) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final h = _groupHomeworks[i];
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.assignment),
                              ),
                              title: Text(
                                h.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Max Score: ${h.maxScore} | Due: ${h.dueAt.year}-${h.dueAt.month}-${h.dueAt.day}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Homework'),
                                      content: const Text(
                                        'Are you sure you want to delete this homework?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    try {
                                      await Supabase.instance.client.rpc(
                                        'delete_homework',
                                        params: {'homework_id': h.id},
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Homework deleted'),
                                          ),
                                        );
                                        _loadGroupDetails();
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                  // Tab 4: Exams
                  const Center(child: Text('Exams workspace for this group.')),
                  // Tab 5: Attendance
                  _groupSessions.isEmpty
                      ? const Center(
                          child: Text(
                            'No attendance sessions found for this group.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _groupSessions.length,
                          separatorBuilder: (ctx, i) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final sess = _groupSessions[i];
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.event_note),
                              ),
                              title: Text(
                                'Session: ${sess.location ?? "Main Hall"}',
                              ),
                              subtitle: Text(
                                'Date: ${sess.sessionDate.year}-${sess.sessionDate.month}-${sess.sessionDate.day} | Status: ${sess.status.name.toUpperCase()}',
                              ),
                            );
                          },
                        ),
                ],
              ),
      ),
    );
  }
}
