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
  List<_StaffQueueItem> _operationsQueue = [];

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
        _fetchOperationsQueue(),
      ]);

      if (!mounted) return;
      setState(() {
        _students = (results[0] as PaginatedResult<Student>).data;
        _groups = results[1] as List<GroupEntity>;
        _leaveQueue = results[2] as List<_StaffQueueItem>;
        _invoiceQueue = results[3] as List<_StaffQueueItem>;
        _attendanceQueue = results[4] as List<_StaffQueueItem>;
        _enrollmentQueue = results[5] as List<_StaffQueueItem>;
        _operationsQueue = results[6] as List<_StaffQueueItem>;
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
              type: _StaffQueueType.leave,
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
          type: _StaffQueueType.invoice,
          id: row['id']?.toString() ?? '',
          title: row['invoice_number']?.toString().isNotEmpty == true
              ? row['invoice_number'].toString()
              : _studentLabel(row['students']),
          subtitle:
              '${_studentLabel(row['students'])} • ${_money(total - paid, currency)} remaining',
          status: row['status']?.toString() ?? 'issued',
          createdAt: DateTime.tryParse(row['due_at']?.toString() ?? ''),
          amountMinor: total - paid,
          currency: currency,
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
              type: _StaffQueueType.attendance,
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
              type: _StaffQueueType.enrollment,
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

  Future<List<_StaffQueueItem>> _fetchOperationsQueue() async {
    return _safeQuery(() async {
      final rows = await Supabase.instance.client.rpc(
        'get_staff_operations_queue',
        params: {'p_limit': 80},
      );
      return (rows as List)
          .whereType<Map>()
          .map((row) => _StaffQueueItem.fromQueueJson(row))
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

  Future<void> _reviewLeaveQueueItem(_StaffQueueItem item, String decision) {
    final noteController = TextEditingController();
    return _runQueueDialog(
      title: decision == 'approved'
          ? 'Approve leave request'
          : 'Reject leave request',
      content: TextField(
        controller: noteController,
        decoration: const InputDecoration(
          labelText: 'Reviewer note',
          prefixIcon: Icon(Icons.notes),
        ),
        minLines: 2,
        maxLines: 4,
      ),
      confirmLabel: decision == 'approved' ? 'Approve' : 'Reject',
      confirmIcon: decision == 'approved' ? Icons.check : Icons.close,
      action: () => Supabase.instance.client.rpc(
        'review_leave_request',
        params: {
          'p_request_id': item.id,
          'p_decision': decision,
          'p_reviewer_note': noteController.text.trim(),
        },
      ),
      successMessage: decision == 'approved'
          ? 'Leave request approved.'
          : 'Leave request rejected.',
      onDispose: noteController.dispose,
    );
  }

  Future<void> _recordCashPayment(_StaffQueueItem item) {
    final amountController = TextEditingController(
      text: (item.amountMinor / 100).toStringAsFixed(
        item.amountMinor % 100 == 0 ? 0 : 2,
      ),
    );
    final noteController = TextEditingController(text: 'Recorded by staff');
    return _runQueueDialog(
      title: 'Record cash payment',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amountController,
            decoration: InputDecoration(
              labelText: 'Amount (${item.currency})',
              prefixIcon: const Icon(Icons.payments),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'Notes',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
        ],
      ),
      confirmLabel: 'Record',
      confirmIcon: Icons.payments,
      action: () {
        final amount = double.tryParse(amountController.text.trim()) ?? 0;
        final amountMinor = (amount * 100).round();
        if (amountMinor <= 0) {
          throw Exception('Payment amount must be greater than zero.');
        }
        return Supabase.instance.client.rpc(
          'record_manual_payment',
          params: {
            'p_invoice_id': item.id,
            'p_amount_minor': amountMinor,
            'p_payment_method': 'cash',
            'p_notes': noteController.text.trim(),
          },
        );
      },
      successMessage: 'Cash payment recorded.',
      onDispose: () {
        amountController.dispose();
        noteController.dispose();
      },
    );
  }

  Future<void> _resolveAttendanceException(
    _StaffQueueItem item,
    String status,
  ) {
    final noteController = TextEditingController(
      text: status == 'excused'
          ? 'Resolved by staff as excused'
          : 'Resolved by staff',
    );
    return _runQueueDialog(
      title: status == 'excused'
          ? 'Mark attendance excused'
          : 'Mark attendance present',
      content: TextField(
        controller: noteController,
        decoration: const InputDecoration(
          labelText: 'Resolution note',
          prefixIcon: Icon(Icons.notes),
        ),
        minLines: 2,
        maxLines: 4,
      ),
      confirmLabel: status == 'excused' ? 'Mark Excused' : 'Mark Present',
      confirmIcon: status == 'excused' ? Icons.event_available : Icons.check,
      action: () => Supabase.instance.client.rpc(
        'staff_update_attendance_exception',
        params: {
          'p_attendance_record_id': item.id,
          'p_attendance_status': status,
          'p_notes': noteController.text.trim(),
        },
      ),
      successMessage: 'Attendance exception resolved.',
      onDispose: noteController.dispose,
    );
  }

  Future<void> _decideAdjustment(_StaffQueueItem item, bool approve) {
    return _runQueueDialog(
      title: approve ? 'Approve adjustment' : 'Reject adjustment',
      content: Text(
        approve
            ? 'This will apply the requested discount or exemption.'
            : 'This will reject the requested discount or exemption.',
      ),
      confirmLabel: approve ? 'Approve' : 'Reject',
      confirmIcon: approve ? Icons.check : Icons.close,
      action: () => Supabase.instance.client.rpc(
        'apply_payment_adjustment_request',
        params: {
          'p_request_id': item.id,
          'p_approve': approve,
          'p_decision_note': approve
              ? 'Approved by staff operations.'
              : 'Rejected by staff operations.',
        },
      ),
      successMessage: approve ? 'Adjustment applied.' : 'Adjustment rejected.',
    );
  }

  Future<void> _runQueueDialog({
    required String title,
    required Widget content,
    required String confirmLabel,
    required IconData confirmIcon,
    required Future<dynamic> Function() action,
    required String successMessage,
    VoidCallback? onDispose,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: Icon(confirmIcon),
            label: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      onDispose?.call();
      return;
    }

    try {
      await action();
      await _loadStaffData();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Operation failed: $e')));
    } finally {
      onDispose?.call();
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
    final openTasks = _operationsQueue.isNotEmpty
        ? _operationsQueue.length
        : _leaveQueue.length + _invoiceQueue.length + _attendanceQueue.length;
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
          items: _operationsQueue.isNotEmpty
              ? _operationsQueue.take(12).toList()
              : [
                  ..._leaveQueue.take(5),
                  ..._invoiceQueue.take(5),
                  ..._attendanceQueue.take(5),
                ],
          onApproveLeave: (item) => _reviewLeaveQueueItem(item, 'approved'),
          onRejectLeave: (item) => _reviewLeaveQueueItem(item, 'rejected'),
          onRecordPayment: _recordCashPayment,
          onMarkExcused: (item) => _resolveAttendanceException(item, 'excused'),
          onMarkPresent: (item) => _resolveAttendanceException(item, 'present'),
          onApproveAdjustment: (item) => _decideAdjustment(item, true),
          onRejectAdjustment: (item) => _decideAdjustment(item, false),
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
        _QueueList(
          emptyText: 'No pending leave requests.',
          items: _leaveQueue,
          onApproveLeave: (item) => _reviewLeaveQueueItem(item, 'approved'),
          onRejectLeave: (item) => _reviewLeaveQueueItem(item, 'rejected'),
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Payment follow-up'),
        const SizedBox(height: 8),
        _QueueList(
          emptyText: 'No invoices need follow-up.',
          items: _invoiceQueue,
          onRecordPayment: _recordCashPayment,
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Attendance exceptions'),
        const SizedBox(height: 8),
        _QueueList(
          emptyText: 'No recent absent or late records.',
          items: _attendanceQueue,
          onMarkExcused: (item) => _resolveAttendanceException(item, 'excused'),
          onMarkPresent: (item) => _resolveAttendanceException(item, 'present'),
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Recent enrollments'),
        const SizedBox(height: 8),
        _QueueList(
          emptyText: 'No recent enrollments visible.',
          items: _enrollmentQueue,
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Unified operations queue'),
        const SizedBox(height: 8),
        _QueueList(
          emptyText:
              'Run the latest operations migration to enable this queue.',
          items: _operationsQueue,
          onApproveLeave: (item) => _reviewLeaveQueueItem(item, 'approved'),
          onRejectLeave: (item) => _reviewLeaveQueueItem(item, 'rejected'),
          onRecordPayment: _recordCashPayment,
          onMarkExcused: (item) => _resolveAttendanceException(item, 'excused'),
          onMarkPresent: (item) => _resolveAttendanceException(item, 'present'),
          onApproveAdjustment: (item) => _decideAdjustment(item, true),
          onRejectAdjustment: (item) => _decideAdjustment(item, false),
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
  final ValueChanged<_StaffQueueItem>? onApproveLeave;
  final ValueChanged<_StaffQueueItem>? onRejectLeave;
  final ValueChanged<_StaffQueueItem>? onRecordPayment;
  final ValueChanged<_StaffQueueItem>? onMarkExcused;
  final ValueChanged<_StaffQueueItem>? onMarkPresent;
  final ValueChanged<_StaffQueueItem>? onApproveAdjustment;
  final ValueChanged<_StaffQueueItem>? onRejectAdjustment;

  const _QueueList({
    required this.emptyText,
    required this.items,
    this.onApproveLeave,
    this.onRejectLeave,
    this.onRecordPayment,
    this.onMarkExcused,
    this.onMarkPresent,
    this.onApproveAdjustment,
    this.onRejectAdjustment,
  });

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
              trailing: [
                PortalStatusChip(status: item.status),
                ..._actionsFor(item),
              ],
            ),
          )
          .toList(),
    );
  }

  List<Widget> _actionsFor(_StaffQueueItem item) {
    return switch (item.type) {
      _StaffQueueType.leave => [
        IconButton(
          tooltip: 'Approve leave',
          onPressed: onApproveLeave == null
              ? null
              : () => onApproveLeave!(item),
          icon: const Icon(Icons.check),
        ),
        IconButton(
          tooltip: 'Reject leave',
          onPressed: onRejectLeave == null ? null : () => onRejectLeave!(item),
          icon: const Icon(Icons.close),
        ),
      ],
      _StaffQueueType.invoice => [
        IconButton(
          tooltip: 'Record cash payment',
          onPressed: onRecordPayment == null
              ? null
              : () => onRecordPayment!(item),
          icon: const Icon(Icons.payments),
        ),
      ],
      _StaffQueueType.attendance => [
        IconButton(
          tooltip: 'Mark excused',
          onPressed: onMarkExcused == null ? null : () => onMarkExcused!(item),
          icon: const Icon(Icons.event_available),
        ),
        IconButton(
          tooltip: 'Mark present',
          onPressed: onMarkPresent == null ? null : () => onMarkPresent!(item),
          icon: const Icon(Icons.check_circle),
        ),
      ],
      _StaffQueueType.adjustment => [
        IconButton(
          tooltip: 'Approve adjustment',
          onPressed: onApproveAdjustment == null
              ? null
              : () => onApproveAdjustment!(item),
          icon: const Icon(Icons.check),
        ),
        IconButton(
          tooltip: 'Reject adjustment',
          onPressed: onRejectAdjustment == null
              ? null
              : () => onRejectAdjustment!(item),
          icon: const Icon(Icons.close),
        ),
      ],
      _StaffQueueType.enrollment => const [],
    };
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

enum _StaffQueueType { leave, invoice, attendance, enrollment, adjustment }

class _StaffQueueItem {
  final _StaffQueueType type;
  final String id;
  final String title;
  final String subtitle;
  final String status;
  final DateTime? createdAt;
  final int amountMinor;
  final String currency;

  const _StaffQueueItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.createdAt,
    this.amountMinor = 0,
    this.currency = 'EGP',
  });

  factory _StaffQueueItem.fromQueueJson(Map raw) {
    final row = Map<String, dynamic>.from(raw);
    final type = switch (row['item_type']?.toString()) {
      'leave' => _StaffQueueType.leave,
      'invoice' => _StaffQueueType.invoice,
      'attendance' => _StaffQueueType.attendance,
      'adjustment' => _StaffQueueType.adjustment,
      _ => _StaffQueueType.enrollment,
    };
    return _StaffQueueItem(
      type: type,
      id: row['item_id']?.toString() ?? '',
      title: row['title']?.toString() ?? 'Operation',
      subtitle: row['subtitle']?.toString() ?? '',
      status: row['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      amountMinor: _asInt(row['amount_minor']),
      currency: row['currency']?.toString() ?? 'EGP',
    );
  }

  IconData get icon {
    return switch (status.toLowerCase()) {
      'pending' => Icons.pending_actions,
      'issued' || 'overdue' || 'partially_paid' => Icons.receipt_long,
      'absent' => Icons.cancel,
      'late' => Icons.schedule,
      'active' => Icons.person_add,
      'applied' => Icons.verified,
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

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
