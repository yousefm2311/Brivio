import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client_wrapper.dart';
import '../../core/security/permission.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/widgets/portal_components.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/academy/presentation/screens/academy_screens.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';

class StaffDashboard extends StatefulWidget {
  final AuthViewModel authViewModel;

  const StaffDashboard({super.key, required this.authViewModel});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  bool _isLoading = false;
  String? _errorMessage;
  int _selectedIndex = 0;
  List<Student> _students = [];
  List<GroupEntity> _groups = [];
  List<_StaffQueueItem> _leaveQueue = [];
  List<_StaffQueueItem> _invoiceQueue = [];
  List<_StaffQueueItem> _attendanceQueue = [];
  List<_StaffQueueItem> _enrollmentQueue = [];

  static const _destinations = [
    PortalDestination(icon: Icons.dashboard_customize, label: 'Overview'),
    PortalDestination(icon: Icons.assignment_late, label: 'Queues'),
    PortalDestination(icon: Icons.school, label: 'Students'),
    PortalDestination(icon: Icons.group_work, label: 'Groups'),
  ];

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  SupabaseClientWrapper get _wrapper =>
      SupabaseClientWrapper(Supabase.instance.client);

  bool _has(Permission permission) =>
      widget.authViewModel.state.hasPermission(permission);

  Future<void> _loadStaffData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final wrapper = _wrapper;
      final studentRepo = SupabaseStudentRepository(wrapper);
      final groupRepo = SupabaseGroupRepository(wrapper);

      final results = await Future.wait<Object>([
        _has(Permission.studentsView)
            ? studentRepo.fetchStudents()
            : Future.value(
                const PaginatedResult<Student>(
                  total: 0,
                  page: 1,
                  pageSize: 20,
                  data: [],
                ),
              ),
        _has(Permission.groupsView)
            ? groupRepo.fetchGroups()
            : Future.value([]),
        _fetchLeaveQueue(),
        _fetchInvoiceQueue(),
        _fetchAttendanceQueue(),
        _fetchEnrollmentQueue(),
      ]);

      if (!mounted) return;
      setState(() {
        _students = (results[0] as PaginatedResult<Student>).data;
        _groups = results[1] as List<GroupEntity>;
        _leaveQueue = results[2] as List<_StaffQueueItem>;
        _invoiceQueue = results[3] as List<_StaffQueueItem>;
        _attendanceQueue = results[4] as List<_StaffQueueItem>;
        _enrollmentQueue = results[5] as List<_StaffQueueItem>;
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

  Future<List<_StaffQueueItem>> _fetchLeaveQueue() async {
    return _safeQuery(() async {
      final rows = await Supabase.instance.client
          .from('leave_requests')
          .select(
            'id, reason, status, submitted_at, students(student_code, profiles(full_name)), class_sessions(session_date, groups(name, code))',
          )
          .eq('status', 'pending')
          .order('submitted_at')
          .limit(30);
      return (rows as List)
          .whereType<Map>()
          .map(
            (row) => _StaffQueueItem(
              id: row['id']?.toString() ?? '',
              title: _studentLabel(row['students']),
              subtitle:
                  '${row['reason'] ?? 'Leave request'} • ${_sessionLabel(row['class_sessions'])}',
              status: row['status']?.toString() ?? 'pending',
              createdAt: DateTime.tryParse(
                row['submitted_at']?.toString() ?? '',
              ),
            ),
          )
          .toList();
    });
  }

  Future<List<_StaffQueueItem>> _fetchInvoiceQueue() async {
    return _safeQuery(() async {
      final rows = await Supabase.instance.client
          .from('invoices')
          .select(
            'id, invoice_number, status, total_minor, amount_paid_minor, currency, due_at, students(student_code, profiles(full_name))',
          )
          .inFilter('status', ['issued', 'overdue', 'partially_paid'])
          .order('due_at')
          .limit(30);
      return (rows as List).whereType<Map>().map((row) {
        final total = row['total_minor'] as int? ?? 0;
        final paid = row['amount_paid_minor'] as int? ?? 0;
        final currency = row['currency']?.toString() ?? 'EGP';
        return _StaffQueueItem(
          id: row['id']?.toString() ?? '',
          title: row['invoice_number']?.toString().isNotEmpty == true
              ? row['invoice_number'].toString()
              : _studentLabel(row['students']),
          subtitle:
              '${_studentLabel(row['students'])} • ${_money(total - paid, currency)} remaining',
          status: row['status']?.toString() ?? 'issued',
          createdAt: DateTime.tryParse(row['due_at']?.toString() ?? ''),
        );
      }).toList();
    });
  }

  Future<List<_StaffQueueItem>> _fetchAttendanceQueue() async {
    return _safeQuery(() async {
      final rows = await Supabase.instance.client
          .from('attendance_records')
          .select(
            'id, attendance_status, marked_at, students(student_code, profiles(full_name)), class_sessions(session_date, groups(name, code))',
          )
          .inFilter('attendance_status', ['absent', 'late'])
          .order('marked_at', ascending: false)
          .limit(30);
      return (rows as List)
          .whereType<Map>()
          .map(
            (row) => _StaffQueueItem(
              id: row['id']?.toString() ?? '',
              title: _studentLabel(row['students']),
              subtitle: _sessionLabel(row['class_sessions']),
              status: row['attendance_status']?.toString() ?? 'unknown',
              createdAt: DateTime.tryParse(row['marked_at']?.toString() ?? ''),
            ),
          )
          .toList();
    });
  }

  Future<List<_StaffQueueItem>> _fetchEnrollmentQueue() async {
    return _safeQuery(() async {
      final rows = await Supabase.instance.client
          .from('enrollments')
          .select(
            'id, status, start_date, students(student_code, profiles(full_name)), groups(name, code)',
          )
          .order('start_date', ascending: false)
          .limit(30);
      return (rows as List)
          .whereType<Map>()
          .map(
            (row) => _StaffQueueItem(
              id: row['id']?.toString() ?? '',
              title: _studentLabel(row['students']),
              subtitle: _groupLabel(row['groups']),
              status: row['status']?.toString() ?? 'active',
              createdAt: DateTime.tryParse(row['start_date']?.toString() ?? ''),
            ),
          )
          .toList();
    });
  }

  Future<List<_StaffQueueItem>> _safeQuery(
    Future<List<_StaffQueueItem>> Function() query,
  ) async {
    try {
      return await query();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authViewModel.currentUser;
    return PortalScaffold(
      title: user?.fullName ?? 'Staff Member',
      subtitle: 'Operations workspace',
      icon: Icons.badge,
      accentColor: AppColors.accent,
      selectedIndex: _selectedIndex,
      destinations: _destinations,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      onRefresh: _loadStaffData,
      onSignOut: widget.authViewModel.signOut,
      body: RefreshIndicator(
        onRefresh: _loadStaffData,
        child: PortalStateView(
          isLoading: _isLoading,
          errorMessage: _errorMessage,
          isEmpty: false,
          emptyTitle: 'No operations data',
          emptySubtitle: 'Refresh after staff permissions are assigned.',
          emptyIcon: Icons.badge,
          onRetry: _loadStaffData,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              PortalHeader(
                eyebrow: 'Operations Portal',
                title: user?.fullName ?? 'Staff Member',
                subtitle: 'Students, groups, attendance, leave, and payments',
                icon: Icons.badge,
                accentColor: AppColors.accent,
              ),
              const SizedBox(height: 16),
              _selectedPage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedPage() {
    return switch (_selectedIndex) {
      0 => _overviewPage(),
      1 => _queuesPage(),
      2 => _studentsPage(),
      3 => _groupsPage(),
      _ => _overviewPage(),
    };
  }

  Widget _overviewPage() {
    final openTasks =
        _leaveQueue.length + _invoiceQueue.length + _attendanceQueue.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalMetricGrid(
          children: [
            PortalMetricCard(
              label: 'Open tasks',
              value: openTasks.toString(),
              icon: Icons.assignment_late,
              accentColor: AppColors.warning,
              onTap: () => setState(() => _selectedIndex = 1),
            ),
            PortalMetricCard(
              label: 'Students visible',
              value: _has(Permission.studentsView)
                  ? _students.length.toString()
                  : 'No access',
              icon: Icons.school,
              accentColor: AppColors.info,
              onTap: _has(Permission.studentsView)
                  ? () => setState(() => _selectedIndex = 2)
                  : null,
            ),
            PortalMetricCard(
              label: 'Groups visible',
              value: _has(Permission.groupsView)
                  ? _groups.length.toString()
                  : 'No access',
              icon: Icons.group_work,
              accentColor: AppColors.accent,
              onTap: _has(Permission.groupsView)
                  ? () => setState(() => _selectedIndex = 3)
                  : null,
            ),
            PortalMetricCard(
              label: 'Recent enrollments',
              value: _enrollmentQueue.length.toString(),
              icon: Icons.person_add,
              accentColor: AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(
          title: 'Priority queue',
          subtitle: 'Pending items that usually need staff follow-up.',
        ),
        const SizedBox(height: 8),
        _QueueList(
          emptyText: 'No priority items right now.',
          items: [
            ..._leaveQueue.take(5),
            ..._invoiceQueue.take(5),
            ..._attendanceQueue.take(5),
          ],
        ),
      ],
    );
  }

  Widget _queuesPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PortalSectionTitle(title: 'Leave requests'),
        const SizedBox(height: 8),
        _QueueList(emptyText: 'No pending leave requests.', items: _leaveQueue),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Payment follow-up'),
        const SizedBox(height: 8),
        _QueueList(
          emptyText: 'No invoices need follow-up.',
          items: _invoiceQueue,
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Attendance exceptions'),
        const SizedBox(height: 8),
        _QueueList(
          emptyText: 'No recent absent or late records.',
          items: _attendanceQueue,
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Recent enrollments'),
        const SizedBox(height: 8),
        _QueueList(
          emptyText: 'No recent enrollments visible.',
          items: _enrollmentQueue,
        ),
      ],
    );
  }

  Widget _studentsPage() {
    if (!_has(Permission.studentsView)) {
      return const _AccessCard(
        message: 'students.view permission is required.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PortalSectionTitle(title: 'Students Directory'),
        const SizedBox(height: 8),
        SizedBox(
          height: 520,
          child: StudentListWidget(students: _students, isLoading: _isLoading),
        ),
      ],
    );
  }

  Widget _groupsPage() {
    if (!_has(Permission.groupsView)) {
      return const _AccessCard(message: 'groups.view permission is required.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PortalSectionTitle(title: 'Groups Roster'),
        const SizedBox(height: 8),
        SizedBox(
          height: 520,
          child: GroupListWidget(groups: _groups, isLoading: _isLoading),
        ),
      ],
    );
  }

  static String _studentLabel(Object? value) {
    final row = _asMap(value);
    final profile = _asMap(row['profiles']);
    final name = profile['full_name']?.toString();
    final code = row['student_code']?.toString();
    if (name != null && name.isNotEmpty && code != null && code.isNotEmpty) {
      return '$name ($code)';
    }
    return name?.isNotEmpty == true ? name! : code ?? 'Student';
  }

  static String _sessionLabel(Object? value) {
    final row = _asMap(value);
    final date = row['session_date']?.toString() ?? 'No date';
    final group = _groupLabel(row['groups']);
    return '$group • $date';
  }

  static String _groupLabel(Object? value) {
    final row = _asMap(value);
    final name = row['name']?.toString();
    final code = row['code']?.toString();
    if (name != null && name.isNotEmpty && code != null && code.isNotEmpty) {
      return '$name ($code)';
    }
    return name?.isNotEmpty == true ? name! : code ?? 'Group';
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static String _money(int minor, String currency) {
    final amount = minor / 100;
    return '${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)} $currency';
  }
}

class _QueueList extends StatelessWidget {
  final String emptyText;
  final List<_StaffQueueItem> items;

  const _QueueList({required this.emptyText, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.inbox_outlined),
              const SizedBox(width: 10),
              Expanded(child: Text(emptyText)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: items
          .map(
            (item) => PortalListCard(
              icon: item.icon,
              accentColor: item.color,
              title: item.title,
              subtitle: '${item.subtitle} • ${item.dateLabel}',
              trailing: [PortalStatusChip(status: item.status)],
            ),
          )
          .toList(),
    );
  }
}

class _AccessCard extends StatelessWidget {
  final String message;

  const _AccessCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.lock_outline),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _StaffQueueItem {
  final String id;
  final String title;
  final String subtitle;
  final String status;
  final DateTime? createdAt;

  const _StaffQueueItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.createdAt,
  });

  IconData get icon {
    return switch (status.toLowerCase()) {
      'pending' => Icons.pending_actions,
      'issued' || 'overdue' || 'partially_paid' => Icons.receipt_long,
      'absent' => Icons.cancel,
      'late' => Icons.schedule,
      'active' => Icons.person_add,
      _ => Icons.assignment,
    };
  }

  Color get color {
    return switch (status.toLowerCase()) {
      'overdue' || 'absent' => AppColors.error,
      'pending' || 'issued' || 'partially_paid' || 'late' => AppColors.warning,
      'active' => AppColors.success,
      _ => AppColors.info,
    };
  }

  String get dateLabel {
    final value = createdAt;
    if (value == null) return 'No date';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
