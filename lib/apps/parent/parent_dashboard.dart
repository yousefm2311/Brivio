import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/di/injection.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/supabase_client_wrapper.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/settings/app_settings_screen.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/widgets/portal_components.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/auth/domain/repositories/i_auth_repository.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/communication/data/repositories/supabase_notification_repository.dart';
import '../../features/communication/domain/repositories/i_notification_repository.dart';
import '../../features/communication/domain/models/notification.dart';
import '../../features/payments/data/repositories/supabase_payment_repositories.dart';
import '../../features/payments/domain/models/payment_models.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/viewmodels/profile_viewmodel.dart';
import '../../features/study_workspace/data/repositories/supabase_student_learning_repository.dart';
import '../../features/study_workspace/domain/models/study_workspace_models.dart';
import 'screens/parent_helpdesk_screen.dart';

class ParentDashboard extends StatefulWidget {
  final AuthViewModel authViewModel;

  const ParentDashboard({super.key, required this.authViewModel});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  bool _isLoading = false;
  bool _isChildLoading = false;
  String? _errorMessage;
  int _selectedIndex = 0;
  List<Student> _linkedChildren = [];
  Student? _selectedChild;
  List<GroupEntity> _childGroups = [];
  StudentLearningSnapshot? _learningSnapshot;
  FinancialSummary? _financialSummary;
  List<Invoice> _invoices = [];
  List<_ParentExamItem> _examItems = [];
  List<_ParentAttendanceItem> _attendance = [];
  List<_ParentLeaveItem> _leaveRequests = [];
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription<AppNotification>? _notificationSubscription;

  static const _destinations = [
    PortalDestination(icon: Icons.dashboard_customize, label: 'Overview'),
    PortalDestination(icon: Icons.school, label: 'Progress'),
    PortalDestination(icon: Icons.fact_check, label: 'Attendance'),
    PortalDestination(icon: Icons.receipt_long, label: 'Payments'),
    PortalDestination(icon: Icons.summarize, label: 'Report'),
    PortalDestination(icon: Icons.notifications, label: 'Notifications'),
    PortalDestination(icon: Icons.support_agent, label: 'Helpdesk'),
    PortalDestination(icon: Icons.account_circle, label: 'Account'),
    PortalDestination(icon: Icons.settings, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _subscribeToNotifications();
    _loadLinkedChildren();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToNotifications() {
    final notificationRepo = getIt<INotificationRepository>();
    _notificationSubscription = notificationRepo
        .subscribeToNotifications()
        .listen((notification) {
          if (!mounted) return;
          setState(() {
            _notifications.insert(0, notification);
            _unreadCount++;
          });
        });
  }

  SupabaseClientWrapper get _wrapper =>
      SupabaseClientWrapper(Supabase.instance.client);

  Future<void> _loadLinkedChildren() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final parentRepo = SupabaseParentRepository(_wrapper);
      final parentId =
          widget.authViewModel.bootstrap?.parentId ??
          widget.authViewModel.bootstrap?.profile.id;
      final children = parentId == null
          ? <Student>[]
          : await parentRepo.fetchLinkedStudents(parentId);
      final previousId = _selectedChild?.id;
      final selected = children.isEmpty
          ? null
          : children.firstWhere(
              (child) => child.id == previousId,
              orElse: () => children.first,
            );

      if (!mounted) return;
      setState(() {
        _linkedChildren = children;
        _selectedChild = selected;
        _isLoading = false;
      });

      if (selected != null) {
        await _loadChildDetails(selected);
      } else {
        _clearChildState();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChildDetails(Student child) async {
    setState(() {
      _isChildLoading = true;
      _errorMessage = null;
    });

    try {
      final wrapper = _wrapper;
      final enrollmentRepo = SupabaseEnrollmentRepository(wrapper);
      final learningRepo = SupabaseStudentLearningRepository(wrapper);
      final paymentRepo = SupabasePaymentRepository(wrapper);
      final invoiceRepo = SupabaseInvoiceRepository(wrapper);
      final notificationRepo = getIt<INotificationRepository>();

      final results = await Future.wait<Object>([
        enrollmentRepo.fetchGroupsForStudent(child.id),
        learningRepo.fetchSnapshotForStudent(child.id),
        paymentRepo.fetchStudentFinancialSummary(child.id),
        invoiceRepo.fetchInvoicesForStudent(child.id),
        _safeList(_fetchExamFeed(child.id)),
        _safeList(_fetchAttendance(child.id)),
        _safeList(_fetchLeaveRequests(child.id)),
        notificationRepo.getNotifications(),
      ]);

      if (!mounted || _selectedChild?.id != child.id) return;
      final childNotifications = _filterNotificationsForChild(
        results[7] as List<AppNotification>,
        child.id,
      );
      setState(() {
        _childGroups = results[0] as List<GroupEntity>;
        _learningSnapshot = results[1] as StudentLearningSnapshot;
        _financialSummary = results[2] as FinancialSummary;
        _invoices = results[3] as List<Invoice>;
        _examItems = results[4] as List<_ParentExamItem>;
        _attendance = results[5] as List<_ParentAttendanceItem>;
        _leaveRequests = results[6] as List<_ParentLeaveItem>;
        _notifications = childNotifications;
        _unreadCount = childNotifications.where((n) => !n.isRead).length;
        _isChildLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isChildLoading = false;
      });
    }
  }

  Future<List<T>> _safeList<T>(Future<List<T>> future) async {
    try {
      return await future;
    } catch (_) {
      return <T>[];
    }
  }

  void _clearChildState() {
    setState(() {
      _childGroups = [];
      _learningSnapshot = null;
      _financialSummary = null;
      _invoices = [];
      _examItems = [];
      _attendance = [];
      _leaveRequests = [];
      _notifications = [];
      _unreadCount = 0;
    });
  }

  List<AppNotification> _filterNotificationsForChild(
    List<AppNotification> notifications,
    String childId,
  ) {
    return notifications
        .toList(); // Simplified since parent gets notifications directly or via referenceId.
  }

  Future<List<_ParentAttendanceItem>> _fetchAttendance(String studentId) async {
    final response = await _wrapper.client.rpc(
      'get_parent_child_attendance_history',
      params: {'p_student_id': studentId, 'p_limit': 80},
    );
    return (response as List)
        .map((row) => _ParentAttendanceItem.fromJson(row as Map))
        .toList();
  }

  Future<List<_ParentLeaveItem>> _fetchLeaveRequests(String studentId) async {
    final response = await _wrapper.client.rpc(
      'get_parent_child_leave_requests',
      params: {'p_student_id': studentId},
    );
    return (response as List)
        .map((row) => _ParentLeaveItem.fromJson(row as Map))
        .toList();
  }

  Future<List<_ParentExamItem>> _fetchExamFeed(String studentId) async {
    final response = await _wrapper.client.rpc(
      'get_parent_child_exam_feed',
      params: {'p_student_id': studentId},
    );
    return (response as List)
        .map((row) => _ParentExamItem.fromJson(row as Map))
        .toList();
  }

  Future<void> _createLeaveRequest() async {
    final child = _selectedChild;
    if (child == null) return;

    final reasonController = TextEditingController();
    String? selectedSessionId = _attendance.isNotEmpty
        ? _attendance.first.classSessionId
        : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Leave request for ${child.fullName}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: selectedSessionId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('Class session'),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(context.tr('General request')),
                    ),
                    ..._attendance.map(
                      (item) => DropdownMenuItem<String?>(
                        value: item.classSessionId,
                        child: Text(
                          '${item.groupName} - ${_formatDate(item.sessionDate)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedSessionId = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: context.tr('Reason'),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.send),
              label: Text(context.tr('Submit')),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (reason.isEmpty) return;

    setState(() => _isChildLoading = true);
    try {
      await _wrapper.client.rpc(
        'create_parent_child_leave_request',
        params: {
          'p_student_id': child.id,
          'p_class_session_id': selectedSessionId,
          'p_reason': reason,
        },
      );
      await _loadChildDetails(child);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isChildLoading = false;
      });
    }
  }

  Future<void> _markAllNotificationsRead() async {
    final repo = SupabaseNotificationRepository(_wrapper);
    await repo.markAllRead();
    final child = _selectedChild;
    if (child != null) await _loadChildDetails(child);
  }

  Future<void> _markNotificationRead(AppNotification notification) async {
    if (notification.isRead) return;
    final repo = SupabaseNotificationRepository(_wrapper);
    await repo.markRead(notification.id);
    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          .map((n) => n.id == notification.id ? n.copyWith(isRead: true) : n)
          .toList();
      if (_unreadCount > 0) _unreadCount--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final parentName = widget.authViewModel.currentUser?.fullName ?? 'Parent';
    final selectedName = _selectedChild?.fullName ?? 'No child selected';

    return PortalScaffold(
      title: parentName,
      subtitle: selectedName,
      icon: Icons.family_restroom,
      accentColor: AppColors.parentRole,
      selectedIndex: _selectedIndex,
      destinations: _destinations,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      onRefresh: _loadLinkedChildren,
      onSignOut: widget.authViewModel.signOut,
      body: RefreshIndicator(
        onRefresh: _loadLinkedChildren,
        child: PortalStateView(
          isLoading: _isLoading,
          errorMessage: null,
          isEmpty: _linkedChildren.isEmpty,
          emptyTitle: 'No linked children',
          emptySubtitle:
              'Ask the academy admin to link your account to a student profile.',
          emptyIcon: Icons.family_restroom,
          onRetry: _loadLinkedChildren,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(),
              if (_isChildLoading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                PortalErrorBanner(
                  message: _errorMessage!,
                  onRetry: _loadLinkedChildren,
                ),
              ],
              const SizedBox(height: 16),
              _buildSelectedPage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return PortalHeader(
      eyebrow: 'Guardian Portal',
      title: _selectedChild?.fullName ?? 'Parent overview',
      subtitle: _selectedChild == null
          ? '${_linkedChildren.length} linked children'
          : '${_selectedChild!.studentCode} • ${_childGroups.length} active groups',
      icon: Icons.family_restroom,
      accentColor: AppColors.parentRole,
      trailing: SizedBox(
        width: 260,
        child: DropdownButtonFormField<Student>(
          initialValue: _selectedChild,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.tr('Child')),
          items: _linkedChildren
              .map(
                (child) => DropdownMenuItem<Student>(
                  value: child,
                  child: Text(
                    '${child.fullName} (${child.studentCode})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (child) {
            if (child == null) return;
            setState(() => _selectedChild = child);
            _loadChildDetails(child);
          },
        ),
      ),
    );
  }

  Widget _buildSelectedPage() {
    return switch (_selectedIndex) {
      0 => _buildOverviewPage(),
      1 => _buildProgressPage(),
      2 => _buildAttendancePage(),
      3 => _buildPaymentsPage(),
      4 => _buildMonthlyReportPage(),
      5 => _buildNotificationsPage(),
      6 => _boundedPortalPage(const ParentHelpdeskScreen()),
      7 => _buildAccountPage(),
      8 => _boundedPortalPage(const AppSettingsPanel()),
      _ => _buildOverviewPage(),
    };
  }

  Widget _boundedPortalPage(Widget child) {
    final height = MediaQuery.sizeOf(context).height;
    return SizedBox(height: height * 0.78, child: child);
  }

  Widget _buildAccountPage() {
    final profile = widget.authViewModel.currentUser;
    final name = profile?.fullName ?? 'Guardian';
    final email = profile?.email ?? '';
    final phone = profile?.phoneNumber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PortalSectionTitle(
          title: 'Account',
          subtitle: 'Manage your guardian profile and app access.',
        ),
        const SizedBox(height: 12),
        PortalListCard(
          icon: Icons.account_circle,
          accentColor: AppColors.parentRole,
          title: name,
          subtitle: [
            if (email.isNotEmpty) email,
            if (phone != null && phone.isNotEmpty) phone,
          ].join(' • '),
          trailing: [
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      viewModel: ProfileViewModel(
                        getIt<IAuthRepository>(),
                        widget.authViewModel.currentUser,
                      ),
                      onSignedOut: widget.authViewModel.signOut,
                    ),
                  ),
                );
                if (mounted) {
                  await widget.authViewModel.restoreSession();
                }
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PortalListCard(
          icon: Icons.notifications_active,
          accentColor: AppColors.parentRole,
          title: 'Notifications',
          subtitle: _unreadCount == 0
              ? 'No unread notifications.'
              : '$_unreadCount unread notifications.',
          trailing: [
            TextButton(
              onPressed: () => setState(() => _selectedIndex = 5),
              child: const Text('Open'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PortalListCard(
          icon: Icons.settings,
          accentColor: AppColors.info,
          title: 'Settings',
          subtitle:
              'Language, theme, notifications, privacy, and biometric login.',
          trailing: [
            TextButton(
              onPressed: () => setState(() => _selectedIndex = 7),
              child: const Text('Open'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PortalListCard(
          icon: Icons.logout,
          accentColor: AppColors.error,
          title: 'Sign out',
          subtitle: 'Leave the guardian portal on this device.',
          trailing: [
            TextButton(
              onPressed: widget.authViewModel.signOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewPage() {
    final progress = _averageProgress();
    final attendanceRate = _attendanceRate();
    final balance = _financialSummary?.remainingBalanceMinor ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalMetricGrid(
          children: [
            PortalMetricCard(
              label: 'Lesson progress',
              value: '${progress.round()}%',
              icon: Icons.trending_up,
              accentColor: AppColors.success,
              onTap: () => setState(() => _selectedIndex = 1),
            ),
            PortalMetricCard(
              label: 'Attendance rate',
              value: '${attendanceRate.round()}%',
              icon: Icons.fact_check,
              accentColor: AppColors.info,
              onTap: () => setState(() => _selectedIndex = 2),
            ),
            PortalMetricCard(
              label: 'Balance due',
              value: _money(balance, _financialSummary?.currency ?? 'EGP'),
              icon: Icons.receipt_long,
              accentColor: balance > 0 ? AppColors.warning : AppColors.success,
              onTap: () => setState(() => _selectedIndex = 3),
            ),
            PortalMetricCard(
              label: 'Unread alerts',
              value: _unreadCount.toString(),
              icon: Icons.notifications_active,
              accentColor: AppColors.parentRole,
              onTap: () => setState(() => _selectedIndex = 5),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ParentInsightPanel(insights: _buildParentInsights()),
        const SizedBox(height: 18),
        const PortalSectionTitle(
          title: 'Active groups',
          subtitle: 'Groups currently assigned to the selected child.',
        ),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: _childGroups.isEmpty,
          emptyText: 'No active groups for this child.',
          children: _childGroups
              .map(
                (group) => PortalListCard(
                  icon: Icons.group_work,
                  accentColor: AppColors.info,
                  title: group.name,
                  subtitle: '${group.code} • ${group.status}',
                  trailing: [PortalStatusChip(status: group.status)],
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Next learning item'),
        const SizedBox(height: 8),
        _buildNextLessonCard(),
      ],
    );
  }

  Widget _buildProgressPage() {
    final snapshot = _learningSnapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalMetricGrid(
          children: (snapshot?.metrics ?? const <StudyMetric>[])
              .map(
                (metric) => PortalMetricCard(
                  label: metric.label,
                  value: metric.value,
                  icon: Icons.insights,
                  accentColor: AppColors.studentRole,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(
          title: 'Exams & grades',
          subtitle: 'Published exams, attempts, scores, and answer review.',
        ),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: _examItems.isEmpty,
          emptyText: 'No exams are visible for this child yet.',
          children: _examItems
              .map(
                (item) => PortalListCard(
                  icon: Icons.quiz,
                  accentColor: item.canReview
                      ? AppColors.success
                      : item.attemptCount > 0
                      ? AppColors.warning
                      : AppColors.info,
                  title: item.title,
                  subtitle:
                      '${item.groupName} | ${item.durationMinutes} min | ${item.attemptCount}/${item.maxAttempts} attempts',
                  trailing: [
                    if (item.scoreLabel != null)
                      PortalStatusChip(status: item.scoreLabel!),
                    PortalStatusChip(
                      status: item.lastAttemptStatus ?? item.status,
                    ),
                  ],
                  onTap: item.canReview
                      ? () => _showParentExamReview(item)
                      : null,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(
          title: 'Published lessons',
          subtitle: 'Progress is calculated from the student reading history.',
        ),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: snapshot == null || snapshot.availableLessons.isEmpty,
          emptyText: 'No published lessons available for this child yet.',
          children: (snapshot?.availableLessons ?? const <StudyLessonSummary>[])
              .map(
                (lesson) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text('${lesson.pathName} • ${lesson.unitName}'),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: lesson.progress),
                        const SizedBox(height: 6),
                        Text(
                          '${lesson.progressPercentage}% • page ${lesson.lastPage}/${lesson.totalPages}',
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildAttendancePage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalMetricGrid(
          children: [
            PortalMetricCard(
              label: 'Present',
              value: _attendance
                  .where((item) => item.status == 'present')
                  .length
                  .toString(),
              icon: Icons.check_circle,
              accentColor: AppColors.success,
            ),
            PortalMetricCard(
              label: 'Absent',
              value: _attendance
                  .where((item) => item.status == 'absent')
                  .length
                  .toString(),
              icon: Icons.cancel,
              accentColor: AppColors.error,
            ),
            PortalMetricCard(
              label: 'Late',
              value: _attendance
                  .where((item) => item.status == 'late')
                  .length
                  .toString(),
              icon: Icons.schedule,
              accentColor: AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'Leave requests',
                subtitle: 'Submit and track absence excuses.',
              ),
            ),
            FilledButton.icon(
              onPressed: _selectedChild == null ? null : _createLeaveRequest,
              icon: const Icon(Icons.add),
              label: Text(context.tr('Request')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: _leaveRequests.isEmpty,
          emptyText: 'No leave requests yet.',
          children: _leaveRequests
              .map(
                (item) => PortalListCard(
                  icon: Icons.event_busy,
                  accentColor: _statusColor(item.status),
                  title: item.reason,
                  subtitle:
                      '${item.groupName} • ${_formatDate(item.submittedAt)}',
                  trailing: [PortalStatusChip(status: item.status)],
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Attendance history'),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: _attendance.isEmpty,
          emptyText: 'No attendance records yet.',
          children: _attendance
              .map(
                (item) => PortalListCard(
                  icon: item.status == 'present'
                      ? Icons.check_circle
                      : item.status == 'late'
                      ? Icons.schedule
                      : Icons.cancel,
                  accentColor: _statusColor(item.status),
                  title: item.groupName,
                  subtitle:
                      '${_formatDate(item.sessionDate)} • ${item.groupCode}',
                  trailing: [PortalStatusChip(status: item.status)],
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPaymentsPage() {
    final summary = _financialSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalMetricGrid(
          children: [
            PortalMetricCard(
              label: 'Invoices',
              value: (summary?.invoiceCount ?? _invoices.length).toString(),
              icon: Icons.receipt,
              accentColor: AppColors.info,
            ),
            PortalMetricCard(
              label: 'Total due',
              value: _money(summary?.totalDueMinor ?? 0, summary?.currency),
              icon: Icons.account_balance_wallet,
              accentColor: AppColors.warning,
            ),
            PortalMetricCard(
              label: 'Paid',
              value: _money(summary?.totalPaidMinor ?? 0, summary?.currency),
              icon: Icons.verified,
              accentColor: AppColors.success,
            ),
            PortalMetricCard(
              label: 'Remaining',
              value: _money(
                summary?.remainingBalanceMinor ?? 0,
                summary?.currency,
              ),
              icon: Icons.pending_actions,
              accentColor: (summary?.remainingBalanceMinor ?? 0) > 0
                  ? AppColors.error
                  : AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Invoices'),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: _invoices.isEmpty,
          emptyText: 'No invoices issued for this child.',
          children: _invoices
              .map(
                (invoice) => PortalListCard(
                  icon: Icons.receipt_long,
                  accentColor: _statusColor(invoice.status),
                  title: invoice.invoiceNumber.isEmpty
                      ? 'Invoice'
                      : invoice.invoiceNumber,
                  subtitle:
                      '${_money(invoice.totalMinor, invoice.currency)} • due ${_formatDate(invoice.dueAt)}',
                  trailing: [PortalStatusChip(status: invoice.status)],
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMonthlyReportPage() {
    final report = _ParentMonthlyReport.fromState(
      attendance: _attendance,
      lessons: _learningSnapshot?.availableLessons ?? const [],
      invoices: _invoices,
      summary: _financialSummary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalSectionTitle(
          title: 'Monthly Report',
          subtitle:
              '${report.monthLabel} summary for ${_selectedChild?.fullName ?? "the selected child"}.',
        ),
        const SizedBox(height: 12),
        PortalMetricGrid(
          children: [
            PortalMetricCard(
              label: 'Attendance',
              value: '${report.attendanceRate.round()}%',
              icon: Icons.fact_check,
              accentColor: report.attendanceRate >= 85
                  ? AppColors.success
                  : AppColors.warning,
            ),
            PortalMetricCard(
              label: 'Lesson progress',
              value: '${report.averageProgress.round()}%',
              icon: Icons.trending_up,
              accentColor: AppColors.studentRole,
            ),
            PortalMetricCard(
              label: 'Completed lessons',
              value: report.completedLessons.toString(),
              icon: Icons.done_all,
              accentColor: AppColors.success,
            ),
            PortalMetricCard(
              label: 'Cash balance',
              value: _money(
                report.remainingBalanceMinor,
                _financialSummary?.currency,
              ),
              icon: Icons.payments,
              accentColor: report.remainingBalanceMinor > 0
                  ? AppColors.error
                  : AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ParentInsightPanel(insights: report.recommendations),
        const SizedBox(height: 18),
        const PortalSectionTitle(
          title: 'Monthly attendance',
          subtitle: 'Only records inside the current month are counted here.',
        ),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: report.monthAttendance.isEmpty,
          emptyText: 'No attendance records in this month yet.',
          children: report.monthAttendance
              .map(
                (item) => PortalListCard(
                  icon: item.status == 'present'
                      ? Icons.check_circle
                      : item.status == 'late'
                      ? Icons.schedule
                      : Icons.cancel,
                  accentColor: _statusColor(item.status),
                  title: item.groupName,
                  subtitle:
                      '${_formatDate(item.sessionDate)} | ${item.groupCode}',
                  trailing: [PortalStatusChip(status: item.status)],
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Payment follow-up'),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: report.openInvoices.isEmpty,
          emptyText: 'No open cash invoices.',
          children: report.openInvoices
              .map(
                (invoice) => PortalListCard(
                  icon: Icons.receipt_long,
                  accentColor: _statusColor(invoice.status),
                  title: invoice.invoiceNumber.isEmpty
                      ? 'Invoice'
                      : invoice.invoiceNumber,
                  subtitle:
                      '${_money(invoice.totalMinor - invoice.amountPaidMinor, invoice.currency)} remaining | due ${_formatDate(invoice.dueAt)}',
                  trailing: [PortalStatusChip(status: invoice.status)],
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildNotificationsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'Notifications',
                subtitle: 'Academy alerts sent to your guardian account.',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _notifications.isEmpty
                  ? null
                  : _markAllNotificationsRead,
              icon: const Icon(Icons.done_all),
              label: Text(context.tr('Mark read')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: _notifications.isEmpty,
          emptyText: 'No notifications yet.',
          children: _notifications
              .map(
                (notification) => PortalListCard(
                  icon: notification.isRead
                      ? Icons.notifications_none
                      : Icons.notifications_active,
                  accentColor: notification.isRead
                      ? AppColors.info
                      : AppColors.parentRole,
                  title: notification.title,
                  subtitle:
                      '${notification.message} • ${_formatDate(notification.createdAt)}',
                  trailing: notification.isRead
                      ? const []
                      : [const PortalStatusChip(status: 'pending')],
                  onTap: () => _openNotification(notification),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  void _openNotification(AppNotification notification) {
    unawaited(_markNotificationRead(notification));
    final pushService = getIt.isRegistered<PushNotificationService>()
        ? getIt<PushNotificationService>()
        : PushNotificationService(_wrapper);
    pushService.handleNotificationTap({
      'type': notification.type,
      'reference_id': notification.referenceId,
      'id': notification.id,
      'title': notification.title,
      'message': notification.message,
    });
  }

  Future<void> _showParentExamReview(_ParentExamItem item) async {
    final child = _selectedChild;
    if (child == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    late final dynamic raw;
    try {
      raw = await _wrapper.client.rpc(
        'get_parent_child_exam_review',
        params: {'p_student_id': child.id, 'p_exam_id': item.id},
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load exam review: $e')));
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    final review = Map<String, dynamic>.from(raw as Map);
    final released = review['released'] == true;
    final answers = (review['answers'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: released
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              review['title']?.toString() ?? item.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Score: ${review['score'] ?? 0} / ${review['max_score'] ?? 0}',
                        style: const TextStyle(
                          color: AppColors.parentRole,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if ((review['teacher_feedback']?.toString() ?? '')
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Teacher feedback: ${review['teacher_feedback']}'),
                      ],
                      const SizedBox(height: 16),
                      Expanded(
                        child: answers.isEmpty
                            ? const Center(child: Text('No answers found.'))
                            : ListView.separated(
                                itemCount: answers.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, index) {
                                  final answer = answers[index];
                                  final isCorrect =
                                      answer['is_correct'] == true;
                                  final color = isCorrect
                                      ? AppColors.success
                                      : AppColors.error;
                                  return DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.08),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.35),
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                isCorrect
                                                    ? Icons.check_circle
                                                    : Icons.cancel,
                                                color: color,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  answer['prompt']
                                                          ?.toString() ??
                                                      '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Student answer: ${answer['student_answer'] ?? '-'}',
                                          ),
                                          Text(
                                            'Correct answer: ${answer['correct_answer'] ?? '-'}',
                                          ),
                                          Text(
                                            'Points: ${answer['points_awarded'] ?? 0} / ${answer['max_points'] ?? 0}',
                                          ),
                                          if ((answer['explanation']
                                                      ?.toString() ??
                                                  '')
                                              .trim()
                                              .isNotEmpty)
                                            Text(
                                              'Explanation: ${answer['explanation']}',
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_clock, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        review['message']?.toString() ??
                            'Results are not released yet.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextLessonCard() {
    final lesson = _learningSnapshot?.nextLesson;
    if (lesson == null) {
      return const _InfoList(
        isEmpty: true,
        emptyText: 'No next lesson available.',
        children: [],
      );
    }
    return PortalListCard(
      icon: lesson.hasPdf ? Icons.picture_as_pdf : Icons.menu_book,
      accentColor: AppColors.studentRole,
      title: lesson.title,
      subtitle:
          '${lesson.pathName} • ${lesson.unitName} • ${lesson.progressPercentage}%',
      trailing: [PortalStatusChip(status: lesson.hasPdf ? 'PDF' : 'Lesson')],
    );
  }

  double _averageProgress() {
    final lessons = _learningSnapshot?.availableLessons ?? [];
    if (lessons.isEmpty) return 0;
    final total = lessons.fold<int>(
      0,
      (sum, lesson) => sum + lesson.progressPercentage,
    );
    return total / lessons.length;
  }

  double _attendanceRate() {
    if (_attendance.isEmpty) return 0;
    final present = _attendance
        .where((item) => item.status == 'present' || item.status == 'late')
        .length;
    return present * 100 / _attendance.length;
  }

  List<_ParentInsight> _buildParentInsights() {
    final insights = <_ParentInsight>[];
    final attendanceRate = _attendanceRate();
    final progress = _averageProgress();
    final balance = _financialSummary?.remainingBalanceMinor ?? 0;
    final absentCount = _attendance
        .where((item) => item.status == 'absent')
        .length;
    final overdueInvoices = _invoices
        .where((invoice) => invoice.status == 'overdue')
        .length;

    if (attendanceRate < 75 && _attendance.isNotEmpty) {
      insights.add(
        _ParentInsight(
          icon: Icons.warning_amber,
          color: AppColors.error,
          title: 'Attendance needs follow-up',
          body:
              'Attendance is ${attendanceRate.round()}% with $absentCount absences.',
        ),
      );
    }
    if (progress < 40 &&
        (_learningSnapshot?.availableLessons.isNotEmpty ?? false)) {
      insights.add(
        _ParentInsight(
          icon: Icons.menu_book,
          color: AppColors.warning,
          title: 'Learning progress is low',
          body: 'Average lesson progress is ${progress.round()}%.',
        ),
      );
    }
    if (balance > 0) {
      insights.add(
        _ParentInsight(
          icon: Icons.payments,
          color: overdueInvoices > 0 ? AppColors.error : AppColors.warning,
          title: overdueInvoices > 0 ? 'Overdue payment' : 'Cash payment due',
          body: '${_money(balance, _financialSummary?.currency)} remaining.',
        ),
      );
    }
    if (_unreadCount > 0) {
      insights.add(
        _ParentInsight(
          icon: Icons.notifications_active,
          color: AppColors.parentRole,
          title: 'Unread academy alerts',
          body: 'There are $_unreadCount unread notifications.',
        ),
      );
    }
    if (insights.isEmpty) {
      insights.add(
        const _ParentInsight(
          icon: Icons.verified,
          color: AppColors.success,
          title: 'No urgent follow-up',
          body: 'Progress, attendance, and payments have no critical alerts.',
        ),
      );
    }
    return insights;
  }

  static String _money(int minor, String? currency) {
    final amount = minor / 100;
    return '${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)} ${currency ?? 'EGP'}';
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return 'No date';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'present' || 'paid' || 'approved' || 'submitted' => AppColors.success,
      'late' || 'pending' || 'issued' => AppColors.warning,
      'absent' || 'overdue' || 'rejected' || 'failed' => AppColors.error,
      _ => AppColors.info,
    };
  }
}

class _InfoList extends StatelessWidget {
  final bool isEmpty;
  final String emptyText;
  final List<Widget> children;

  const _InfoList({
    required this.isEmpty,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 10),
              Expanded(child: Text(context.l10n.t(emptyText))),
            ],
          ),
        ),
      );
    }
    return Column(children: children);
  }
}

class _ParentInsight {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _ParentInsight({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

class _ParentInsightPanel extends StatelessWidget {
  final List<_ParentInsight> insights;

  const _ParentInsightPanel({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PortalSectionTitle(
              title: 'Guardian Insights',
              subtitle: 'Important follow-up points from real student data.',
            ),
            const SizedBox(height: 12),
            ...insights.map(
              (insight) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(insight.icon, color: insight.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.t(insight.title),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(context.l10n.t(insight.body)),
                        ],
                      ),
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

class _ParentMonthlyReport {
  final String monthLabel;
  final List<_ParentAttendanceItem> monthAttendance;
  final List<Invoice> openInvoices;
  final double attendanceRate;
  final double averageProgress;
  final int completedLessons;
  final int remainingBalanceMinor;
  final List<_ParentInsight> recommendations;

  const _ParentMonthlyReport({
    required this.monthLabel,
    required this.monthAttendance,
    required this.openInvoices,
    required this.attendanceRate,
    required this.averageProgress,
    required this.completedLessons,
    required this.remainingBalanceMinor,
    required this.recommendations,
  });

  factory _ParentMonthlyReport.fromState({
    required List<_ParentAttendanceItem> attendance,
    required List<StudyLessonSummary> lessons,
    required List<Invoice> invoices,
    required FinancialSummary? summary,
  }) {
    final now = DateTime.now();
    final monthAttendance = attendance.where((item) {
      final date = item.sessionDate;
      return date != null && date.year == now.year && date.month == now.month;
    }).toList();
    final present = monthAttendance
        .where(
          (item) =>
              item.status == 'present' ||
              item.status == 'late' ||
              item.status == 'excused',
        )
        .length;
    final attendanceRate = monthAttendance.isEmpty
        ? 0.0
        : present * 100 / monthAttendance.length;
    final averageProgress = lessons.isEmpty
        ? 0.0
        : lessons.fold<int>(
                0,
                (sum, lesson) => sum + lesson.progressPercentage,
              ) /
              lessons.length;
    final completedLessons = lessons
        .where((lesson) => lesson.progressPercentage >= 100)
        .length;
    final openInvoices = invoices
        .where(
          (invoice) =>
              invoice.status == 'issued' ||
              invoice.status == 'overdue' ||
              invoice.status == 'partially_paid',
        )
        .toList();
    final remaining = summary?.remainingBalanceMinor ?? 0;
    final recommendations = <_ParentInsight>[];

    if (attendanceRate < 85 && monthAttendance.isNotEmpty) {
      recommendations.add(
        _ParentInsight(
          icon: Icons.event_busy,
          color: AppColors.warning,
          title: 'Improve attendance consistency',
          body:
              'This month attendance is ${attendanceRate.round()}%. Follow up before the next session.',
        ),
      );
    }
    if (averageProgress < 50 && lessons.isNotEmpty) {
      recommendations.add(
        _ParentInsight(
          icon: Icons.schedule,
          color: AppColors.warning,
          title: 'Add a fixed study block',
          body:
              'Average progress is ${averageProgress.round()}%. A short daily review would help.',
        ),
      );
    }
    if (remaining > 0) {
      recommendations.add(
        _ParentInsight(
          icon: Icons.receipt_long,
          color: AppColors.error,
          title: 'Settle cash balance',
          body: 'There is an open balance that should be paid at the academy.',
        ),
      );
    }
    if (recommendations.isEmpty) {
      recommendations.add(
        const _ParentInsight(
          icon: Icons.verified,
          color: AppColors.success,
          title: 'Monthly status is stable',
          body: 'No urgent attendance, progress, or payment action is needed.',
        ),
      );
    }

    return _ParentMonthlyReport(
      monthLabel: '${now.year}-${now.month.toString().padLeft(2, '0')}',
      monthAttendance: monthAttendance,
      openInvoices: openInvoices,
      attendanceRate: attendanceRate,
      averageProgress: averageProgress,
      completedLessons: completedLessons,
      remainingBalanceMinor: remaining,
      recommendations: recommendations,
    );
  }
}

class _ParentExamItem {
  final String id;
  final String title;
  final String? description;
  final String? groupId;
  final String groupName;
  final int durationMinutes;
  final int maxAttempts;
  final String status;
  final String? lastAttemptStatus;
  final int attemptCount;
  final double? lastScore;
  final double? maxScore;

  const _ParentExamItem({
    required this.id,
    required this.title,
    required this.description,
    required this.groupId,
    required this.groupName,
    required this.durationMinutes,
    required this.maxAttempts,
    required this.status,
    required this.lastAttemptStatus,
    required this.attemptCount,
    required this.lastScore,
    required this.maxScore,
  });

  bool get canReview =>
      lastAttemptStatus == 'submitted' ||
      lastAttemptStatus == 'graded' ||
      lastAttemptStatus == 'expired';

  String? get scoreLabel {
    if (lastScore == null) return null;
    final score = lastScore == lastScore!.roundToDouble()
        ? lastScore!.toStringAsFixed(0)
        : lastScore!.toStringAsFixed(1);
    final max = maxScore == null
        ? ''
        : maxScore == maxScore!.roundToDouble()
        ? ' / ${maxScore!.toStringAsFixed(0)}'
        : ' / ${maxScore!.toStringAsFixed(1)}';
    return '$score$max';
  }

  factory _ParentExamItem.fromJson(Map json) {
    return _ParentExamItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Exam',
      description: json['description']?.toString(),
      groupId: json['group_id']?.toString(),
      groupName: json['group_name']?.toString() ?? 'Group',
      durationMinutes: (json['duration_minutes'] as num? ?? 30).toInt(),
      maxAttempts: (json['max_attempts'] as num? ?? 1).toInt(),
      status: json['status']?.toString() ?? 'published',
      lastAttemptStatus: json['last_attempt_status']?.toString(),
      attemptCount: (json['attempt_count'] as num? ?? 0).toInt(),
      lastScore: (json['last_score'] as num?)?.toDouble(),
      maxScore: (json['max_score'] as num?)?.toDouble(),
    );
  }
}

class _ParentAttendanceItem {
  final String id;
  final String classSessionId;
  final String status;
  final DateTime? markedAt;
  final DateTime? sessionDate;
  final String groupName;
  final String groupCode;

  const _ParentAttendanceItem({
    required this.id,
    required this.classSessionId,
    required this.status,
    required this.markedAt,
    required this.sessionDate,
    required this.groupName,
    required this.groupCode,
  });

  factory _ParentAttendanceItem.fromJson(Map json) {
    return _ParentAttendanceItem(
      id: json['id']?.toString() ?? '',
      classSessionId: json['class_session_id']?.toString() ?? '',
      status: json['attendance_status']?.toString() ?? 'unknown',
      markedAt: DateTime.tryParse(json['marked_at']?.toString() ?? ''),
      sessionDate: DateTime.tryParse(json['session_date']?.toString() ?? ''),
      groupName: json['group_name']?.toString() ?? 'Group',
      groupCode: json['group_code']?.toString() ?? '',
    );
  }
}

class _ParentLeaveItem {
  final String id;
  final String reason;
  final String status;
  final DateTime? submittedAt;
  final DateTime? sessionDate;
  final String groupName;

  const _ParentLeaveItem({
    required this.id,
    required this.reason,
    required this.status,
    required this.submittedAt,
    required this.sessionDate,
    required this.groupName,
  });

  factory _ParentLeaveItem.fromJson(Map json) {
    return _ParentLeaveItem(
      id: json['id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? 'Leave request',
      status: json['status']?.toString() ?? 'pending',
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      sessionDate: DateTime.tryParse(json['session_date']?.toString() ?? ''),
      groupName: json['group_name']?.toString() ?? 'General',
    );
  }
}
