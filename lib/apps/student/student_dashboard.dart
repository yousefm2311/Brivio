import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client_wrapper.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/widgets/portal_components.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/academy/presentation/screens/academy_screens.dart';
import '../../features/auth/data/repositories/supabase_auth_repository.dart';
import '../../features/auth/domain/models/user_profile.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/communication/data/repositories/supabase_announcement_repository.dart';
import '../../features/communication/data/repositories/supabase_notification_repository.dart';
import '../../features/communication/domain/models/announcement.dart';
import '../../features/communication/domain/models/notification.dart';
import '../../features/payments/data/repositories/supabase_payment_repositories.dart';
import '../../features/payments/domain/models/payment_models.dart';
import '../../features/study_workspace/data/repositories/supabase_student_learning_repository.dart';
import '../../features/study_workspace/data/repositories/supabase_study_workspace_repository.dart';
import '../../features/study_workspace/domain/models/study_workspace_models.dart';
import '../../features/study_workspace/presentation/screens/study_workspace_screen.dart';

class StudentDashboard extends StatefulWidget {
  final AuthViewModel authViewModel;

  const StudentDashboard({super.key, required this.authViewModel});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  String? _loadError;
  List<GroupEntity> _enrolledGroups = [];
  StudentLearningSnapshot? _snapshot;
  FinancialSummary? _financialSummary;
  List<Invoice> _invoices = [];
  List<Receipt> _receipts = [];
  List<Announcement> _announcements = [];
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStudentLearning();
  }

  Future<void> _loadStudentLearning() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final studentId = widget.authViewModel.bootstrap?.studentId;
      if (studentId == null) {
        if (!mounted) return;
        setState(() {
          _enrolledGroups = [];
          _snapshot = null;
          _isLoading = false;
        });
        return;
      }

      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final enrollmentRepo = SupabaseEnrollmentRepository(wrapper);
      final learningRepo = SupabaseStudentLearningRepository(wrapper);
      final paymentRepo = SupabasePaymentRepository(wrapper);
      final invoiceRepo = SupabaseInvoiceRepository(wrapper);
      final receiptRepo = SupabaseReceiptRepository(wrapper);
      final announcementRepo = SupabaseAnnouncementRepository(wrapper);
      final notificationRepo = SupabaseNotificationRepository(wrapper);

      final results = await Future.wait([
        enrollmentRepo.fetchGroupsForStudent(studentId),
        learningRepo.fetchSnapshotForStudent(studentId),
        paymentRepo.fetchStudentFinancialSummary(studentId),
        invoiceRepo.fetchInvoicesForStudent(studentId),
        receiptRepo.fetchReceiptsForStudent(studentId),
        announcementRepo.getTargetedAnnouncements(),
        notificationRepo.getNotifications(),
        notificationRepo.getUnreadCount(),
      ]);

      final groups = results[0] as List<GroupEntity>;

      if (!mounted) return;
      setState(() {
        _enrolledGroups = groups;
        _snapshot = results[1] as StudentLearningSnapshot;
        _financialSummary = results[2] as FinancialSummary;
        _invoices = results[3] as List<Invoice>;
        _receipts = results[4] as List<Receipt>;
        _announcements = results[5] as List<Announcement>;
        _notifications = results[6] as List<AppNotification>;
        _unreadCount = results[7] as int;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openWorkspace(StudyLessonSummary lesson) {
    final studentId = widget.authViewModel.bootstrap?.studentId;
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudyWorkspaceScreen(
          lesson: lesson,
          studentId: studentId,
          repository: SupabaseStudyWorkspaceRepository(wrapper),
        ),
      ),
    );
  }

  Future<void> _markNotificationRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      await SupabaseNotificationRepository(wrapper).markRead(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map(
              (item) => item.id == notification.id
                  ? item.copyWith(readAt: DateTime.now())
                  : item,
            )
            .toList();
        if (_unreadCount > 0) _unreadCount--;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Notification update failed: $e')));
    }
  }

  Future<void> _markAllNotificationsRead() async {
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      await SupabaseNotificationRepository(wrapper).markAllRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((item) => item.copyWith(readAt: DateTime.now()))
            .toList();
        _unreadCount = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Notification update failed: $e')));
    }
  }

  Future<void> _acknowledgeAnnouncement(Announcement announcement) async {
    if (announcement.isAcknowledged) return;
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      await SupabaseAnnouncementRepository(
        wrapper,
      ).acknowledgeAnnouncement(announcement.id);
      if (!mounted) return;
      setState(() {
        _announcements = _announcements
            .map(
              (item) => item.id == announcement.id
                  ? item.copyWith(
                      readAt: DateTime.now(),
                      acknowledgedAt: DateTime.now(),
                    )
                  : item,
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Acknowledgement failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authViewModel.currentUser;
    final nextLesson = _snapshot?.nextLesson;

    final pages = [
      _StudentOverviewPage(
        userName: user?.fullName ?? 'Student',
        isLoading: _isLoading,
        errorMessage: _loadError,
        snapshot: _snapshot,
        enrolledGroups: _enrolledGroups,
        financialSummary: _financialSummary,
        unreadCount: _unreadCount,
        onRetry: _loadStudentLearning,
        onOpenWorkspace: nextLesson == null
            ? null
            : () => _openWorkspace(nextLesson),
        onNavigate: (index) => setState(() => _selectedIndex = index),
      ),
      _StudentLessonsPage(
        isLoading: _isLoading,
        lessons: _snapshot?.availableLessons ?? const [],
        onOpenLesson: _openWorkspace,
      ),
      _StudentGroupsPage(isLoading: _isLoading, groups: _enrolledGroups),
      _StudentAnnouncementsPage(
        isLoading: _isLoading,
        announcements: _announcements,
        onAcknowledge: _acknowledgeAnnouncement,
      ),
      _StudentNotificationsPage(
        isLoading: _isLoading,
        notifications: _notifications,
        unreadCount: _unreadCount,
        onMarkRead: _markNotificationRead,
        onMarkAllRead: _markAllNotificationsRead,
      ),
      _StudentBillingPage(
        isLoading: _isLoading,
        summary: _financialSummary,
        invoices: _invoices,
        receipts: _receipts,
      ),
      _StudentAccountPage(
        profile: user,
        role: widget.authViewModel.userRole?.displayName ?? 'Student',
        studentId: widget.authViewModel.bootstrap?.studentId,
        onSignOut: widget.authViewModel.signOut,
        onProfileChanged: widget.authViewModel.restoreSession,
      ),
    ];

    return PortalScaffold(
      title: 'CodeStart',
      subtitle: 'Student portal',
      icon: Icons.school,
      accentColor: AppColors.studentRole,
      selectedIndex: _selectedIndex,
      destinations: const [
        PortalDestination(icon: Icons.dashboard, label: 'Overview'),
        PortalDestination(icon: Icons.menu_book, label: 'Lessons'),
        PortalDestination(icon: Icons.group_work, label: 'Groups'),
        PortalDestination(icon: Icons.campaign, label: 'Announcements'),
        PortalDestination(icon: Icons.notifications, label: 'Notifications'),
        PortalDestination(icon: Icons.receipt_long, label: 'Billing'),
        PortalDestination(icon: Icons.account_circle, label: 'Account'),
      ],
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      onRefresh: _loadStudentLearning,
      onSignOut: widget.authViewModel.signOut,
      body: pages[_selectedIndex],
    );
  }
}

class _StudentOverviewPage extends StatelessWidget {
  final String userName;
  final bool isLoading;
  final String? errorMessage;
  final StudentLearningSnapshot? snapshot;
  final List<GroupEntity> enrolledGroups;
  final FinancialSummary? financialSummary;
  final int unreadCount;
  final VoidCallback onRetry;
  final VoidCallback? onOpenWorkspace;
  final ValueChanged<int> onNavigate;

  const _StudentOverviewPage({
    required this.userName,
    required this.isLoading,
    required this.errorMessage,
    required this.snapshot,
    required this.enrolledGroups,
    required this.financialSummary,
    required this.unreadCount,
    required this.onRetry,
    required this.onOpenWorkspace,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final nextLesson = snapshot?.nextLesson;
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeroPanel(
            studentName: userName,
            isLoading: isLoading,
            lesson: nextLesson,
            onOpenWorkspace: onOpenWorkspace,
          ),
          const SizedBox(height: 18),
          if (errorMessage != null) ...[
            PortalErrorBanner(message: errorMessage!, onRetry: onRetry),
            const SizedBox(height: 18),
          ],
          PortalMetricGrid(
            children: [
              PortalMetricCard(
                label: 'Available Lessons',
                value: (snapshot?.availableLessons.length ?? 0).toString(),
                icon: Icons.menu_book,
                accentColor: AppColors.studentRole,
                onTap: () => onNavigate(1),
              ),
              PortalMetricCard(
                label: 'Active Groups',
                value: enrolledGroups.length.toString(),
                icon: Icons.group_work,
                accentColor: AppColors.info,
                onTap: () => onNavigate(2),
              ),
              PortalMetricCard(
                label: 'Unread',
                value: unreadCount.toString(),
                icon: Icons.notifications,
                accentColor: AppColors.warning,
                onTap: () => onNavigate(4),
              ),
              PortalMetricCard(
                label: 'Balance',
                value: _formatMoney(
                  financialSummary?.remainingBalanceMinor ?? 0,
                  financialSummary?.currency ?? 'EGP',
                ),
                icon: Icons.receipt_long,
                accentColor: AppColors.error,
                onTap: () => onNavigate(5),
              ),
            ],
          ),
          if ((snapshot?.metrics ?? const []).isNotEmpty) ...[
            const SizedBox(height: 18),
            _MetricGrid(metrics: snapshot?.metrics ?? const []),
          ],
          const SizedBox(height: 18),
          _SectionHeader(
            title: 'Today',
            actionLabel: nextLesson == null ? null : 'Open workspace',
            onAction: onOpenWorkspace,
          ),
          const SizedBox(height: 10),
          if (nextLesson == null)
            _NoPublishedContentState(
              isLoading: isLoading,
              hasEnrollment: enrolledGroups.isNotEmpty,
            )
          else
            _LearningPathCard(lesson: nextLesson, onOpen: onOpenWorkspace!),
          const SizedBox(height: 18),
          const _SectionHeader(title: 'My active groups'),
          const SizedBox(height: 10),
          SizedBox(
            height: 360,
            child: GroupListWidget(
              groups: enrolledGroups,
              isLoading: isLoading,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentLessonsPage extends StatelessWidget {
  final bool isLoading;
  final List<StudyLessonSummary> lessons;
  final ValueChanged<StudyLessonSummary> onOpenLesson;

  const _StudentLessonsPage({
    required this.isLoading,
    required this.lessons,
    required this.onOpenLesson,
  });

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'My Lessons',
      subtitle: 'Published lessons assigned to your active groups.',
      icon: Icons.menu_book,
      accentColor: AppColors.studentRole,
      child: PortalStateView(
        isLoading: isLoading,
        errorMessage: null,
        isEmpty: lessons.isEmpty,
        emptyTitle: 'No lessons available',
        emptySubtitle: 'Lessons appear here after your teacher publishes them.',
        emptyIcon: Icons.menu_book,
        onRetry: () {},
        child: ListView.separated(
          itemCount: lessons.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final lesson = lessons[index];
            return PortalListCard(
              icon: Icons.play_circle_outline,
              accentColor: AppColors.studentRole,
              title: lesson.title,
              subtitle:
                  '${lesson.pathName} | ${lesson.unitName} | ${lesson.estimatedMinutes} min | ${lesson.progressPercentage}% complete',
              trailing: [
                if (lesson.hasPdf)
                  const Icon(Icons.picture_as_pdf, color: AppColors.error),
                if (lesson.hasCodePlayground)
                  const Icon(Icons.terminal, color: AppColors.success),
                IconButton(
                  tooltip: 'Open lesson',
                  onPressed: () => onOpenLesson(lesson),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StudentGroupsPage extends StatelessWidget {
  final bool isLoading;
  final List<GroupEntity> groups;

  const _StudentGroupsPage({required this.isLoading, required this.groups});

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'My Groups',
      subtitle: 'Your current learning groups and enrollment status.',
      icon: Icons.group_work,
      accentColor: AppColors.info,
      child: SizedBox.expand(
        child: GroupListWidget(groups: groups, isLoading: isLoading),
      ),
    );
  }
}

class _StudentAnnouncementsPage extends StatelessWidget {
  final bool isLoading;
  final List<Announcement> announcements;
  final ValueChanged<Announcement> onAcknowledge;

  const _StudentAnnouncementsPage({
    required this.isLoading,
    required this.announcements,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'Announcements',
      subtitle: 'Published updates from your academy and teachers.',
      icon: Icons.campaign,
      accentColor: AppColors.warning,
      child: PortalStateView(
        isLoading: isLoading,
        errorMessage: null,
        isEmpty: announcements.isEmpty,
        emptyTitle: 'No announcements',
        emptySubtitle: 'Targeted announcements will appear here.',
        emptyIcon: Icons.campaign,
        onRetry: () {},
        child: ListView.separated(
          itemCount: announcements.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = announcements[index];
            final urgent = item.priority == AnnouncementPriority.urgent;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          urgent ? Icons.warning : Icons.campaign,
                          color: urgent ? AppColors.error : AppColors.info,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        PortalStatusChip(status: item.priority.name),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(item.body),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Published ${_formatDate(item.publishAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (item.requiresAcknowledgement)
                          item.isAcknowledged
                              ? const PortalStatusChip(status: 'acknowledged')
                              : FilledButton.icon(
                                  onPressed: () => onAcknowledge(item),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Acknowledge'),
                                ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StudentNotificationsPage extends StatelessWidget {
  final bool isLoading;
  final List<AppNotification> notifications;
  final int unreadCount;
  final ValueChanged<AppNotification> onMarkRead;
  final VoidCallback onMarkAllRead;

  const _StudentNotificationsPage({
    required this.isLoading,
    required this.notifications,
    required this.unreadCount,
    required this.onMarkRead,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'Notifications',
      subtitle:
          '$unreadCount unread notification${unreadCount == 1 ? "" : "s"}.',
      icon: Icons.notifications,
      accentColor: AppColors.warning,
      actions: [
        if (unreadCount > 0)
          PortalAction(
            icon: Icons.done_all,
            label: 'Mark all read',
            onPressed: onMarkAllRead,
            primary: true,
          ),
      ],
      child: PortalStateView(
        isLoading: isLoading,
        errorMessage: null,
        isEmpty: notifications.isEmpty,
        emptyTitle: 'No notifications',
        emptySubtitle: 'Academic and payment alerts will appear here.',
        emptyIcon: Icons.notifications_none,
        onRetry: () {},
        child: ListView.separated(
          itemCount: notifications.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = notifications[index];
            return PortalListCard(
              icon: item.isRead
                  ? Icons.notifications_none
                  : Icons.notifications,
              accentColor: item.isRead ? AppColors.info : AppColors.warning,
              title: item.title,
              subtitle: '${item.body} | ${_formatDate(item.createdAt)}',
              trailing: [
                if (!item.isRead)
                  IconButton(
                    tooltip: 'Mark read',
                    onPressed: () => onMarkRead(item),
                    icon: const Icon(Icons.check_circle_outline),
                  ),
              ],
              onTap: () => onMarkRead(item),
            );
          },
        ),
      ),
    );
  }
}

class _StudentBillingPage extends StatelessWidget {
  final bool isLoading;
  final FinancialSummary? summary;
  final List<Invoice> invoices;
  final List<Receipt> receipts;

  const _StudentBillingPage({
    required this.isLoading,
    required this.summary,
    required this.invoices,
    required this.receipts,
  });

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'Billing',
      subtitle: 'Invoices, balances, and receipts from real finance records.',
      icon: Icons.receipt_long,
      accentColor: AppColors.error,
      child: PortalStateView(
        isLoading: isLoading,
        errorMessage: null,
        isEmpty: summary == null && invoices.isEmpty && receipts.isEmpty,
        emptyTitle: 'No billing records',
        emptySubtitle: 'Invoices appear here when a subscription is assigned.',
        emptyIcon: Icons.receipt_long,
        onRetry: () {},
        child: ListView(
          children: [
            if (summary != null)
              PortalMetricGrid(
                children: [
                  PortalMetricCard(
                    label: 'Invoices',
                    value: summary!.invoiceCount.toString(),
                    icon: Icons.receipt_long,
                    accentColor: AppColors.info,
                  ),
                  PortalMetricCard(
                    label: 'Total Due',
                    value: _formatMoney(
                      summary!.totalDueMinor,
                      summary!.currency,
                    ),
                    icon: Icons.payments,
                    accentColor: AppColors.warning,
                  ),
                  PortalMetricCard(
                    label: 'Paid',
                    value: _formatMoney(
                      summary!.totalPaidMinor,
                      summary!.currency,
                    ),
                    icon: Icons.check_circle,
                    accentColor: AppColors.success,
                  ),
                  PortalMetricCard(
                    label: 'Balance',
                    value: _formatMoney(
                      summary!.remainingBalanceMinor,
                      summary!.currency,
                    ),
                    icon: Icons.account_balance_wallet,
                    accentColor: AppColors.error,
                  ),
                ],
              ),
            const SizedBox(height: 18),
            const PortalSectionTitle(title: 'Invoices'),
            const SizedBox(height: 10),
            if (invoices.isEmpty)
              const _InlineEmptyState(
                icon: Icons.receipt_long,
                text: 'No invoices issued.',
              )
            else
              ...invoices.map(
                (invoice) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PortalListCard(
                    icon: Icons.receipt_long,
                    accentColor: invoice.status == 'paid'
                        ? AppColors.success
                        : AppColors.warning,
                    title: invoice.invoiceNumber,
                    subtitle:
                        'Due ${_formatDate(invoice.dueAt)} | Paid ${_formatMoney(invoice.amountPaidMinor, invoice.currency)} of ${_formatMoney(invoice.totalMinor, invoice.currency)}',
                    trailing: [PortalStatusChip(status: invoice.status)],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            const PortalSectionTitle(title: 'Receipts'),
            const SizedBox(height: 10),
            if (receipts.isEmpty)
              const _InlineEmptyState(
                icon: Icons.receipt,
                text: 'No receipts generated yet.',
              )
            else
              ...receipts.map(
                (receipt) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PortalListCard(
                    icon: Icons.receipt,
                    accentColor: AppColors.success,
                    title: receipt.receiptNumber.isEmpty
                        ? 'Receipt ${receipt.id.substring(0, 8)}'
                        : receipt.receiptNumber,
                    subtitle:
                        '${_formatMoney(receipt.amountMinor, receipt.currency)} | Issued ${_formatDate(receipt.issuedAt)}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StudentAccountPage extends StatefulWidget {
  final UserProfile? profile;
  final String role;
  final String? studentId;
  final VoidCallback onSignOut;
  final Future<void> Function() onProfileChanged;

  const _StudentAccountPage({
    required this.profile,
    required this.role,
    required this.studentId,
    required this.onSignOut,
    required this.onProfileChanged,
  });

  @override
  State<_StudentAccountPage> createState() => _StudentAccountPageState();
}

class _StudentAccountPageState extends State<_StudentAccountPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _avatarController;
  final TextEditingController _passwordController = TextEditingController();
  bool _isSavingProfile = false;
  bool _isChangingPassword = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController = TextEditingController(text: profile?.fullName ?? '');
    _phoneController = TextEditingController(text: profile?.phoneNumber ?? '');
    _avatarController = TextEditingController(text: profile?.avatarUrl ?? '');
  }

  @override
  void didUpdateWidget(covariant _StudentAccountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.id != widget.profile?.id ||
        oldWidget.profile?.updatedAt != widget.profile?.updatedAt) {
      _nameController.text = widget.profile?.fullName ?? '';
      _phoneController.text = widget.profile?.phoneNumber ?? '';
      _avatarController.text = widget.profile?.avatarUrl ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _avatarController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final profile = widget.profile;
    if (profile == null || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSavingProfile = true;
      _message = null;
      _error = null;
    });
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final repo = SupabaseAuthRepository(wrapper);
      await repo.updateProfile(
        profile.copyWith(
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          avatarUrl: _avatarController.text.trim().isEmpty
              ? null
              : _avatarController.text.trim(),
        ),
      );
      await widget.onProfileChanged();
      if (!mounted) return;
      setState(() {
        _isSavingProfile = false;
        _message = 'Profile updated successfully.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSavingProfile = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _changePassword() async {
    final password = _passwordController.text.trim();
    if (password.length < 6) {
      setState(() {
        _message = null;
        _error = 'Password must be at least 6 characters.';
      });
      return;
    }
    setState(() {
      _isChangingPassword = true;
      _message = null;
      _error = null;
    });
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final repo = SupabaseAuthRepository(wrapper);
      await repo.updatePassword(password);
      _passwordController.clear();
      if (!mounted) return;
      setState(() {
        _isChangingPassword = false;
        _message = 'Password updated successfully.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChangingPassword = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return PortalPageShell(
      title: 'Account',
      subtitle: 'Manage your student identity and password.',
      icon: Icons.account_circle,
      accentColor: AppColors.studentRole,
      actions: [
        PortalAction(
          icon: Icons.logout,
          label: 'Sign out',
          onPressed: widget.onSignOut,
          primary: true,
        ),
      ],
      child: ListView(
        children: [
          if (_message != null) ...[
            _InlineNotice(
              icon: Icons.check_circle,
              color: AppColors.success,
              text: _message!,
            ),
            const SizedBox(height: 10),
          ],
          if (_error != null) ...[
            _InlineNotice(
              icon: Icons.error_outline,
              color: AppColors.error,
              text: _error!,
            ),
            const SizedBox(height: 10),
          ],
          PortalListCard(
            icon: Icons.person,
            accentColor: AppColors.studentRole,
            title: profile?.fullName ?? 'Student',
            subtitle: (profile?.email ?? '').isEmpty
                ? widget.role
                : '${widget.role} | ${profile!.email}',
          ),
          const SizedBox(height: 8),
          PortalListCard(
            icon: Icons.badge,
            accentColor: AppColors.info,
            title: 'Student profile',
            subtitle:
                'Student ID: ${widget.studentId ?? "Not linked"} | Branch: ${profile?.branchId ?? "Not assigned"}',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PortalSectionTitle(
                      title: 'Profile Details',
                      subtitle: 'Update the information shown in your account.',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _avatarController,
                      decoration: const InputDecoration(
                        labelText: 'Avatar image URL',
                        prefixIcon: Icon(Icons.image_outlined),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _isSavingProfile ? null : _saveProfile,
                      icon: _isSavingProfile
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Save Profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PortalSectionTitle(
                    title: 'Password',
                    subtitle: 'Change your password for the current account.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _isChangingPassword ? null : _changePassword,
                    icon: _isChangingPassword
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.key),
                    label: const Text('Update Password'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InlineNotice({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineEmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

String _formatMoney(int minor, String currency) {
  final value = minor / 100;
  final clean = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '$clean $currency';
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _HeroPanel extends StatelessWidget {
  final String studentName;
  final bool isLoading;
  final StudyLessonSummary? lesson;
  final VoidCallback? onOpenWorkspace;

  const _HeroPanel({
    required this.studentName,
    required this.isLoading,
    required this.lesson,
    required this.onOpenWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $studentName',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your learning workspace opens only from published lessons assigned to your active groups.',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: theme.colorScheme.primary,
                ),
                onPressed: onOpenWorkspace,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  onOpenWorkspace == null ? 'No lesson ready' : 'Resume lesson',
                ),
              ),
            ],
          );
          final progress = _HeroProgressCard(
            isLoading: isLoading,
            lesson: lesson,
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: intro),
                const SizedBox(width: 20),
                Expanded(flex: 4, child: progress),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [intro, const SizedBox(height: 16), progress],
          );
        },
      ),
    );
  }
}

class _HeroProgressCard extends StatelessWidget {
  final bool isLoading;
  final StudyLessonSummary? lesson;

  const _HeroProgressCard({required this.isLoading, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            const LinearProgressIndicator()
          else if (lesson == null) ...[
            const Text(
              'No published lesson is available.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enroll the student and publish curriculum content to start.',
              style: TextStyle(color: Colors.white),
            ),
          ] else ...[
            Text(
              lesson!.pathName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: lesson!.progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              '${lesson!.progressPercentage}% complete',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<StudyMetric> metrics;

  const _MetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 124,
          ),
          itemBuilder: (context, index) => _MetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final StudyMetric metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 10),
            Text(
              metric.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(metric.helper, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.open_in_new),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _LearningPathCard extends StatelessWidget {
  final StudyLessonSummary lesson;
  final VoidCallback onOpen;

  const _LearningPathCard({required this.lesson, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              child: Icon(Icons.code),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${lesson.unitName} - ${lesson.estimatedMinutes} min'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (lesson.hasPdf)
                        const _FeaturePill(
                          icon: Icons.picture_as_pdf,
                          label: 'PDF',
                        ),
                      const _FeaturePill(icon: Icons.draw, label: 'Notebook'),
                      if (lesson.hasCodePlayground)
                        const _FeaturePill(icon: Icons.terminal, label: 'Code'),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Open lesson',
              onPressed: onOpen,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _NoPublishedContentState extends StatelessWidget {
  final bool isLoading;
  final bool hasEnrollment;

  const _NoPublishedContentState({
    required this.isLoading,
    required this.hasEnrollment,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.menu_book_outlined, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasEnrollment
                    ? 'You are enrolled, but no published lessons are available yet.'
                    : 'You are not enrolled in any active group yet.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
