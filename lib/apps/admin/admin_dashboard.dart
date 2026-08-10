import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client_wrapper.dart';
import '../../core/settings/app_settings_screen.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/widgets/portal_components.dart';
import '../../features/admin/presentation/screens/data_import_screen.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/academy/presentation/screens/branch_management_screen.dart';
import '../../features/academy/presentation/screens/group_management_screen.dart';
import '../../features/academy/presentation/screens/schedule_management_screen.dart';
import '../../features/academy/presentation/screens/subject_management_screen.dart';
import '../../features/assessment/presentation/screens/exam_management_screen.dart';
import '../../features/assessment/presentation/screens/homework_management_screen.dart';
import '../../features/assessment/presentation/screens/question_bank_screen.dart';
import '../../features/attendance/presentation/screens/attendance_operations_screen.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/curriculum/presentation/screens/curriculum_editor_screen.dart';
import '../../features/payments/presentation/screens/finance_management_screen.dart';
import '../../features/people/presentation/screens/parent_management_screen.dart';
import '../../features/people/presentation/screens/staff_management_screen.dart';
import '../../features/people/presentation/screens/student_management_screen.dart';
import '../../features/people/presentation/screens/teacher_management_screen.dart';
import '../../features/security/presentation/screens/rbac_management_screen.dart';
import '../../features/security/presentation/screens/audit_log_screen.dart';
import '../../features/study_workspace/presentation/screens/study_replay_screen.dart';

class AdminDashboard extends StatefulWidget {
  final AuthViewModel authViewModel;

  const AdminDashboard({super.key, required this.authViewModel});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<Student> _students = [];
  List<Parent> _parents = [];
  List<Teacher> _teachers = [];
  List<Branch> _branches = [];
  List<SubjectEntity> _subjects = [];
  List<GroupEntity> _groups = [];
  AcademyCoreSummary? _summary;
  int _parentTotal = 0;
  _AdminOpsMetrics _opsMetrics = const _AdminOpsMetrics();
  List<_AdminActivityItem> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadSummaryData();
  }

  Future<void> _loadSummaryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final studentRepo = SupabaseStudentRepository(wrapper);
      final parentRepo = SupabaseParentRepository(wrapper);
      final teacherRepo = SupabaseTeacherRepository(wrapper);
      final branchRepo = SupabaseBranchRepository(wrapper);
      final subjectRepo = SupabaseSubjectRepository(wrapper);
      final groupRepo = SupabaseGroupRepository(wrapper);
      final summaryRepo = SupabaseAcademySummaryRepository(wrapper);

      final results = await Future.wait([
        studentRepo.fetchStudents(),
        parentRepo.fetchParents(),
        teacherRepo.fetchTeachers(),
        branchRepo.fetchBranches(),
        subjectRepo.fetchSubjects(),
        groupRepo.fetchGroups(),
        summaryRepo.fetchSummary(),
        _fetchOpsMetrics(),
        _fetchRecentActivity(),
      ]);

      if (!mounted) return;
      setState(() {
        _students = (results[0] as PaginatedResult<Student>).data;
        final parentResult = results[1] as PaginatedResult<Parent>;
        _parents = parentResult.data;
        _parentTotal = parentResult.total;
        _teachers = (results[2] as PaginatedResult<Teacher>).data;
        _branches = results[3] as List<Branch>;
        _subjects = results[4] as List<SubjectEntity>;
        _groups = results[5] as List<GroupEntity>;
        _summary = results[6] as AcademyCoreSummary;
        _opsMetrics = results[7] as _AdminOpsMetrics;
        _recentActivity = results[8] as List<_AdminActivityItem>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<_AdminOpsMetrics> _fetchOpsMetrics() async {
    final client = Supabase.instance.client;
    final today = DateTime.now().toIso8601String().split('T').first;
    final results = await Future.wait<List<dynamic>>([
      _safeList(
        () => client
            .from('class_sessions')
            .select('id')
            .eq('session_date', today),
      ),
      _safeList(
        () => client.from('attendance_records').select('id').inFilter(
          'attendance_status',
          ['absent', 'late'],
        ),
      ),
      _safeList(
        () =>
            client.from('leave_requests').select('id').eq('status', 'pending'),
      ),
      _safeList(
        () => client
            .from('homework_submissions')
            .select('id')
            .eq('status', 'submitted'),
      ),
      _safeList(
        () => client.from('invoices').select('id').inFilter('status', [
          'issued',
          'overdue',
          'partially_paid',
        ]),
      ),
      _safeList(
        () => client.from('lessons').select('id').eq('status', 'published'),
      ),
      _safeList(
        () => client
            .from('class_session_boards')
            .select('id')
            .eq('is_published', true),
      ),
    ]);

    return _AdminOpsMetrics(
      todaySessions: results[0].length,
      attendanceExceptions: results[1].length,
      pendingLeaves: results[2].length,
      gradingQueue: results[3].length,
      openInvoices: results[4].length,
      publishedLessons: results[5].length,
      publishedBoards: results[6].length,
    );
  }

  Future<List<_AdminActivityItem>> _fetchRecentActivity() async {
    final client = Supabase.instance.client;
    final activity = <_AdminActivityItem>[];

    final leaves = await _safeList(
      () => client
          .from('leave_requests')
          .select('id, reason, status, submitted_at')
          .order('submitted_at', ascending: false)
          .limit(6),
    );
    activity.addAll(
      leaves.map(
        (row) => _AdminActivityItem.fromMap(
          row,
          title: row['reason']?.toString() ?? 'Leave request',
          type: 'Leave',
          dateKey: 'submitted_at',
        ),
      ),
    );

    final invoices = await _safeList(
      () => client
          .from('invoices')
          .select('id, invoice_number, status, due_at')
          .order('due_at')
          .limit(6),
    );
    activity.addAll(
      invoices.map(
        (row) => _AdminActivityItem.fromMap(
          row,
          title: row['invoice_number']?.toString().isNotEmpty == true
              ? row['invoice_number'].toString()
              : 'Invoice',
          type: 'Finance',
          dateKey: 'due_at',
        ),
      ),
    );

    final enrollments = await _safeList(
      () => client
          .from('enrollments')
          .select('id, status, start_date')
          .order('start_date', ascending: false)
          .limit(6),
    );
    activity.addAll(
      enrollments.map(
        (row) => _AdminActivityItem.fromMap(
          row,
          title: 'Student enrollment',
          type: 'Enrollment',
          dateKey: 'start_date',
        ),
      ),
    );

    activity.sort((a, b) {
      final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return activity.take(12).toList();
  }

  Future<List<dynamic>> _safeList(Future<dynamic> Function() query) async {
    try {
      final result = await query();
      return result is List ? result : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _AdminOverview(
        authViewModel: widget.authViewModel,
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        students: _students,
        parents: _parents,
        teachers: _teachers,
        branches: _branches,
        subjects: _subjects,
        groups: _groups,
        summary: _summary,
        parentTotal: _parentTotal,
        opsMetrics: _opsMetrics,
        recentActivity: _recentActivity,
        onRetry: _loadSummaryData,
        onNavigate: (index) => setState(() => _selectedIndex = index),
      ),
      const BranchManagementScreen(),
      const SubjectManagementScreen(),
      const GroupManagementScreen(),
      const ScheduleManagementScreen(),
      const StudentManagementScreen(),
      const ParentManagementScreen(),
      const TeacherManagementScreen(),
      const StaffManagementScreen(),
      const CurriculumEditorScreen(),
      const QuestionBankScreen(),
      const HomeworkManagementScreen(),
      const ExamManagementScreen(),
      const AttendanceOperationsScreen(),
      const FinanceManagementScreen(),
      const RbacManagementScreen(),
      const AuditLogScreen(),
      const StudyReplayScreen(),
      const DataImportScreen(),
      const AppSettingsScreen(),
    ];

    return PortalScaffold(
      title: 'Academy Suite',
      subtitle: 'Admin operations',
      icon: Icons.admin_panel_settings,
      accentColor: AppColors.adminRole,
      selectedIndex: _selectedIndex,
      destinations: const [
        PortalDestination(icon: Icons.dashboard, label: 'Overview'),
        PortalDestination(icon: Icons.domain, label: 'Branches'),
        PortalDestination(icon: Icons.book, label: 'Subjects'),
        PortalDestination(icon: Icons.group_work, label: 'Groups'),
        PortalDestination(icon: Icons.schedule, label: 'Schedules'),
        PortalDestination(icon: Icons.school, label: 'Students'),
        PortalDestination(icon: Icons.family_restroom, label: 'Parents'),
        PortalDestination(icon: Icons.person, label: 'Teachers'),
        PortalDestination(icon: Icons.badge, label: 'Staff'),
        PortalDestination(icon: Icons.auto_stories, label: 'Curriculum'),
        PortalDestination(icon: Icons.help_outline, label: 'Questions'),
        PortalDestination(icon: Icons.assignment, label: 'Homework'),
        PortalDestination(icon: Icons.quiz, label: 'Exams'),
        PortalDestination(icon: Icons.event_note, label: 'Attendance'),
        PortalDestination(icon: Icons.monetization_on, label: 'Finance'),
        PortalDestination(icon: Icons.security, label: 'Security'),
        PortalDestination(icon: Icons.manage_search, label: 'Audit'),
        PortalDestination(icon: Icons.video_library, label: 'Replay'),
        PortalDestination(icon: Icons.upload_file, label: 'Import'),
        PortalDestination(icon: Icons.settings, label: 'Settings'),
      ],
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      onRefresh: _loadSummaryData,
      onSignOut: widget.authViewModel.signOut,
      body: pages[_selectedIndex],
    );
  }
}

class _AdminOverview extends StatelessWidget {
  final AuthViewModel authViewModel;
  final bool isLoading;
  final String? errorMessage;
  final List<Student> students;
  final List<Parent> parents;
  final List<Teacher> teachers;
  final List<Branch> branches;
  final List<SubjectEntity> subjects;
  final List<GroupEntity> groups;
  final AcademyCoreSummary? summary;
  final int parentTotal;
  final _AdminOpsMetrics opsMetrics;
  final List<_AdminActivityItem> recentActivity;
  final VoidCallback onRetry;
  final ValueChanged<int> onNavigate;

  const _AdminOverview({
    required this.authViewModel,
    required this.isLoading,
    required this.errorMessage,
    required this.students,
    required this.parents,
    required this.teachers,
    required this.branches,
    required this.subjects,
    required this.groups,
    required this.summary,
    required this.parentTotal,
    required this.opsMetrics,
    required this.recentActivity,
    required this.onRetry,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final user = authViewModel.currentUser;
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PortalHeader(
            eyebrow: 'Admin Portal',
            title: 'Welcome, ${user?.fullName ?? "Administrator"}',
            subtitle:
                '${authViewModel.userRole?.displayName ?? "Admin"} - ${user?.branchId ?? "Global access"}',
            icon: Icons.admin_panel_settings,
            accentColor: AppColors.adminRole,
            trailing: IconButton.filledTonal(
              tooltip: 'Refresh',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            PortalErrorBanner(message: errorMessage!, onRetry: onRetry),
          ],
          const SizedBox(height: 18),
          const PortalSectionTitle(
            title: 'Academy Operations',
            subtitle: 'Live counts from the production database.',
          ),
          const SizedBox(height: 12),
          PortalMetricGrid(
            children: [
              PortalMetricCard(
                label: 'Branches',
                value: (summary?.activeBranches ?? branches.length).toString(),
                icon: Icons.domain,
                accentColor: Colors.indigo,
                onTap: () => onNavigate(1),
              ),
              PortalMetricCard(
                label: 'Subjects',
                value: (summary?.activeSubjects ?? subjects.length).toString(),
                icon: Icons.book,
                accentColor: Colors.deepOrange,
                onTap: () => onNavigate(2),
              ),
              PortalMetricCard(
                label: 'Groups',
                value: (summary?.activeGroups ?? groups.length).toString(),
                icon: Icons.group_work,
                accentColor: Colors.blue,
                onTap: () => onNavigate(3),
              ),
              PortalMetricCard(
                label: 'Students',
                value: (summary?.activeStudents ?? students.length).toString(),
                icon: Icons.school,
                accentColor: Colors.green,
                onTap: () => onNavigate(5),
              ),
              PortalMetricCard(
                label: 'Parents',
                value: (parentTotal == 0 ? parents.length : parentTotal)
                    .toString(),
                icon: Icons.family_restroom,
                accentColor: Colors.orange,
                onTap: () => onNavigate(6),
              ),
              PortalMetricCard(
                label: 'Teachers',
                value: (summary?.activeTeachers ?? teachers.length).toString(),
                icon: Icons.person,
                accentColor: Colors.purple,
                onTap: () => onNavigate(7),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const PortalSectionTitle(
            title: 'Setup Readiness',
            subtitle: 'Minimum data needed for a usable production rollout.',
          ),
          const SizedBox(height: 8),
          _SetupReadinessCard(
            items: [
              _SetupCheck(
                'Branches',
                branches.isNotEmpty,
                onTap: () => onNavigate(1),
              ),
              _SetupCheck(
                'Subjects',
                subjects.isNotEmpty,
                onTap: () => onNavigate(2),
              ),
              _SetupCheck(
                'Groups',
                groups.isNotEmpty,
                onTap: () => onNavigate(3),
              ),
              _SetupCheck(
                'Students',
                students.isNotEmpty,
                onTap: () => onNavigate(5),
              ),
              _SetupCheck(
                'Teachers',
                teachers.isNotEmpty,
                onTap: () => onNavigate(7),
              ),
              _SetupCheck(
                'Parents',
                parentTotal > 0 || parents.isNotEmpty,
                onTap: () => onNavigate(6),
              ),
              _SetupCheck(
                'Published lessons',
                opsMetrics.publishedLessons > 0,
                onTap: () => onNavigate(9),
              ),
              _SetupCheck(
                'Finance records',
                opsMetrics.openInvoices > 0,
                onTap: () => onNavigate(14),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const PortalSectionTitle(
            title: 'Runtime Analytics',
            subtitle: 'Operational workload currently visible to admins.',
          ),
          const SizedBox(height: 12),
          PortalMetricGrid(
            children: [
              PortalMetricCard(
                label: 'Today sessions',
                value: opsMetrics.todaySessions.toString(),
                icon: Icons.today,
                accentColor: AppColors.info,
                onTap: () => onNavigate(13),
              ),
              PortalMetricCard(
                label: 'Attendance exceptions',
                value: opsMetrics.attendanceExceptions.toString(),
                icon: Icons.assignment_late,
                accentColor: AppColors.warning,
                onTap: () => onNavigate(13),
              ),
              PortalMetricCard(
                label: 'Pending leaves',
                value: opsMetrics.pendingLeaves.toString(),
                icon: Icons.event_busy,
                accentColor: AppColors.warning,
                onTap: () => onNavigate(13),
              ),
              PortalMetricCard(
                label: 'Grading queue',
                value: opsMetrics.gradingQueue.toString(),
                icon: Icons.grading,
                accentColor: AppColors.primary,
                onTap: () => onNavigate(11),
              ),
              PortalMetricCard(
                label: 'Open invoices',
                value: opsMetrics.openInvoices.toString(),
                icon: Icons.receipt_long,
                accentColor: AppColors.error,
                onTap: () => onNavigate(14),
              ),
              PortalMetricCard(
                label: 'Published boards',
                value: opsMetrics.publishedBoards.toString(),
                icon: Icons.draw,
                accentColor: AppColors.success,
                onTap: () => onNavigate(13),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: PortalSectionTitle(
                  title: 'Export',
                  subtitle: 'Copy CSV snapshots from the data loaded here.',
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _copyStudentsCsv(context),
                    icon: const Icon(Icons.school),
                    label: const Text('Students CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _copyGroupsCsv(context),
                    icon: const Icon(Icons.group_work),
                    label: const Text('Groups CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _copyTeachersCsv(context),
                    icon: const Icon(Icons.person),
                    label: const Text('Teachers CSV'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const PortalSectionTitle(
            title: 'Recent Activity',
            subtitle: 'Latest leave, invoice, and enrollment records.',
          ),
          const SizedBox(height: 8),
          _ActivityList(items: recentActivity),
        ],
      ),
    );
  }

  Future<void> _copyStudentsCsv(BuildContext context) async {
    final rows = [
      ['id', 'student_code', 'full_name', 'email', 'grade_level', 'status'],
      ...students.map(
        (s) => [
          s.id,
          s.studentCode,
          s.fullName,
          s.email,
          s.gradeLevel ?? '',
          s.status,
        ],
      ),
    ];
    await _copyCsv(context, 'Students CSV copied', rows);
  }

  Future<void> _copyGroupsCsv(BuildContext context) async {
    final rows = [
      ['id', 'code', 'name', 'subject_id', 'branch_id', 'status'],
      ...groups.map(
        (g) => [g.id, g.code, g.name, g.subjectId, g.branchId, g.status],
      ),
    ];
    await _copyCsv(context, 'Groups CSV copied', rows);
  }

  Future<void> _copyTeachersCsv(BuildContext context) async {
    final rows = [
      ['id', 'full_name', 'email', 'specialization'],
      ...teachers.map(
        (t) => [t.id, t.fullName, t.email, t.specialization ?? ''],
      ),
    ];
    await _copyCsv(context, 'Teachers CSV copied', rows);
  }

  Future<void> _copyCsv(
    BuildContext context,
    String message,
    List<List<String>> rows,
  ) async {
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}

class _AdminOpsMetrics {
  final int todaySessions;
  final int attendanceExceptions;
  final int pendingLeaves;
  final int gradingQueue;
  final int openInvoices;
  final int publishedLessons;
  final int publishedBoards;

  const _AdminOpsMetrics({
    this.todaySessions = 0,
    this.attendanceExceptions = 0,
    this.pendingLeaves = 0,
    this.gradingQueue = 0,
    this.openInvoices = 0,
    this.publishedLessons = 0,
    this.publishedBoards = 0,
  });
}

class _AdminActivityItem {
  final String title;
  final String type;
  final String status;
  final DateTime? date;

  const _AdminActivityItem({
    required this.title,
    required this.type,
    required this.status,
    required this.date,
  });

  factory _AdminActivityItem.fromMap(
    Map row, {
    required String title,
    required String type,
    required String dateKey,
  }) {
    return _AdminActivityItem(
      title: title,
      type: type,
      status: row['status']?.toString() ?? 'active',
      date: DateTime.tryParse(row[dateKey]?.toString() ?? ''),
    );
  }

  String get dateLabel {
    final value = date;
    if (value == null) return 'No date';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class _SetupCheck {
  final String label;
  final bool isReady;
  final VoidCallback onTap;

  const _SetupCheck(this.label, this.isReady, {required this.onTap});
}

class _SetupReadinessCard extends StatelessWidget {
  final List<_SetupCheck> items;

  const _SetupReadinessCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final ready = items.where((item) => item.isReady).length;
    final percent = items.isEmpty ? 0.0 : ready / items.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$ready/${items.length}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map(
                    (item) => ActionChip(
                      avatar: Icon(
                        item.isReady ? Icons.check_circle : Icons.error_outline,
                        color: item.isReady
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      label: Text(item.label),
                      onPressed: item.onTap,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  final List<_AdminActivityItem> items;

  const _ActivityList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.history),
              SizedBox(width: 10),
              Expanded(child: Text('No recent activity visible yet.')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: items
          .map(
            (item) => PortalListCard(
              icon: _iconForType(item.type),
              accentColor: _colorForStatus(item.status),
              title: item.title,
              subtitle: '${item.type} • ${item.dateLabel}',
              trailing: [PortalStatusChip(status: item.status)],
            ),
          )
          .toList(),
    );
  }

  static IconData _iconForType(String type) {
    return switch (type) {
      'Leave' => Icons.event_busy,
      'Finance' => Icons.receipt_long,
      'Enrollment' => Icons.person_add,
      _ => Icons.history,
    };
  }

  static Color _colorForStatus(String status) {
    return switch (status.toLowerCase()) {
      'active' || 'paid' || 'approved' => AppColors.success,
      'pending' || 'issued' || 'partially_paid' => AppColors.warning,
      'overdue' || 'rejected' || 'failed' => AppColors.error,
      _ => AppColors.info,
    };
  }
}
