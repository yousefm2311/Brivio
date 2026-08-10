import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/supabase_client_wrapper.dart';
import '../../core/settings/app_settings_screen.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/widgets/portal_components.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/academy/presentation/screens/academy_screens.dart';
import '../../features/assessment/data/repositories/supabase_assessment_repositories.dart';
import '../../features/assessment/domain/models/assessment_models.dart';
import '../../features/assessment/presentation/screens/assessment_screens.dart';
import '../../features/attendance/presentation/screens/student_qr_attendance_screen.dart';
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
  List<_PublishedSessionBoard> _sessionBoards = [];
  List<_StudentHomeworkItem> _homeworkItems = [];
  List<_StudentExamItem> _examItems = [];
  List<_StudentAttendanceItem> _attendanceItems = [];
  List<_StudentLeaveItem> _leaveItems = [];
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
        _fetchPublishedSessionBoards(),
        _fetchStudentHomeworkFeed(),
        _fetchStudentExamFeed(),
        _fetchStudentAttendanceHistory(),
        _fetchStudentLeaveRequests(),
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
        _sessionBoards = results[8] as List<_PublishedSessionBoard>;
        _homeworkItems = results[9] as List<_StudentHomeworkItem>;
        _examItems = results[10] as List<_StudentExamItem>;
        _attendanceItems = results[11] as List<_StudentAttendanceItem>;
        _leaveItems = results[12] as List<_StudentLeaveItem>;
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

  Future<List<_StudentHomeworkItem>> _fetchStudentHomeworkFeed() async {
    final rows = await Supabase.instance.client.rpc(
      'get_student_homework_feed',
    );
    return (rows as List)
        .whereType<Map>()
        .map((row) => _StudentHomeworkItem.fromJson(row))
        .toList();
  }

  Future<List<_StudentExamItem>> _fetchStudentExamFeed() async {
    final rows = await Supabase.instance.client.rpc('get_student_exam_feed');
    return (rows as List)
        .whereType<Map>()
        .map((row) => _StudentExamItem.fromJson(row))
        .toList();
  }

  Future<List<_StudentAttendanceItem>> _fetchStudentAttendanceHistory() async {
    final rows = await Supabase.instance.client.rpc(
      'get_current_student_attendance_history',
      params: {'p_limit': 120},
    );
    return (rows as List)
        .whereType<Map>()
        .map((row) => _StudentAttendanceItem.fromJson(row))
        .toList();
  }

  Future<List<_StudentLeaveItem>> _fetchStudentLeaveRequests() async {
    final rows = await Supabase.instance.client.rpc(
      'get_current_student_leave_requests',
    );
    return (rows as List)
        .whereType<Map>()
        .map((row) => _StudentLeaveItem.fromJson(row))
        .toList();
  }

  Future<void> _createLeaveRequest() async {
    final reasonController = TextEditingController();
    String? selectedSessionId = _attendanceItems.isEmpty
        ? null
        : _attendanceItems.first.classSessionId;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(context.tr('Request Leave')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: selectedSessionId,
                  decoration: InputDecoration(
                    labelText: context.tr('Session'),
                    prefixIcon: const Icon(Icons.event),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(context.tr('General leave request')),
                    ),
                    for (final item in _attendanceItems.take(30))
                      DropdownMenuItem<String?>(
                        value: item.classSessionId,
                        child: Text(
                          '${_formatDate(item.sessionDate)} - ${item.groupName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedSessionId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: context.tr('Reason'),
                    alignLabelWithHint: true,
                  ),
                  minLines: 3,
                  maxLines: 6,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.send),
              label: Text(context.tr('Send')),
            ),
          ],
        ),
      ),
    );

    if (submitted != true) {
      reasonController.dispose();
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'create_student_leave_request',
        params: {
          'p_class_session_id': selectedSessionId,
          'p_reason': reasonController.text.trim(),
        },
      );
      await _loadStudentLearning();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Leave request sent.'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Leave request failed: $e')));
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _submitHomework(_StudentHomeworkItem item) async {
    final textController = TextEditingController();
    final attachmentController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Submit ${item.homework.title}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  labelText: context.tr('Answer / notes'),
                  alignLabelWithHint: true,
                ),
                minLines: 4,
                maxLines: 8,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: attachmentController,
                decoration: InputDecoration(
                  labelText: context.tr('Attachment URL'),
                  prefixIcon: const Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.upload_file),
            label: Text(context.tr('Submit')),
          ),
        ],
      ),
    );
    if (submitted != true) {
      textController.dispose();
      attachmentController.dispose();
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'submit_homework_text',
        params: {
          'p_homework_id': item.homework.id,
          'p_submission_text': textController.text.trim(),
          'p_attachment_url': attachmentController.text.trim().isEmpty
              ? null
              : attachmentController.text.trim(),
        },
      );
      await _loadStudentLearning();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Homework submitted.'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
    } finally {
      textController.dispose();
      attachmentController.dispose();
    }
  }

  Future<void> _startExam(_StudentExamItem item) async {
    final groupId = item.exam.groupId;
    if (groupId == null) return;
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final repo = SupabaseExamRepository(wrapper);
      final exams = await repo.fetchExamsForGroup(groupId);
      final exam = exams.firstWhere((exam) => exam.id == item.exam.id);
      final attempt = await repo.startExam(exam.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExamRunnerScreen(
            exam: exam,
            attempt: attempt,
            onOptionSelected: (questionId, optionId) {
              repo.saveExamAnswer(
                attemptId: attempt.id,
                questionId: questionId,
                selectedOptionId: optionId,
              );
            },
            onSubmit: () async {
              await repo.submitExamAttempt(attempt.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),
      );
      await _loadStudentLearning();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exam failed: $e')));
    }
  }

  Future<List<_PublishedSessionBoard>> _fetchPublishedSessionBoards() async {
    final rows = await Supabase.instance.client.rpc(
      'get_student_published_session_boards',
    );

    return (rows as List)
        .whereType<Map>()
        .map((row) => _PublishedSessionBoard.fromJson(row))
        .toList();
  }

  void _openSessionBoard(_PublishedSessionBoard board) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _StudentSessionBoardScreen(board: board),
      ),
    );
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
      _StudentAssessmentsPage(
        isLoading: _isLoading,
        homeworkItems: _homeworkItems,
        examItems: _examItems,
        onSubmitHomework: _submitHomework,
        onStartExam: _startExam,
      ),
      _StudentAttendancePage(
        isLoading: _isLoading,
        attendanceItems: _attendanceItems,
        leaveItems: _leaveItems,
        onCreateLeaveRequest: _createLeaveRequest,
        onScanQr: _scanAttendanceQr,
      ),
      _StudentGroupsPage(isLoading: _isLoading, groups: _enrolledGroups),
      _StudentSessionBoardsPage(
        isLoading: _isLoading,
        boards: _sessionBoards,
        onOpenBoard: _openSessionBoard,
      ),
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
      const AppSettingsScreen(),
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
        PortalDestination(icon: Icons.assignment, label: 'Assessments'),
        PortalDestination(icon: Icons.event_available, label: 'Attendance'),
        PortalDestination(icon: Icons.group_work, label: 'Groups'),
        PortalDestination(icon: Icons.draw, label: 'Boards'),
        PortalDestination(icon: Icons.campaign, label: 'Announcements'),
        PortalDestination(icon: Icons.notifications, label: 'Notifications'),
        PortalDestination(icon: Icons.receipt_long, label: 'Billing'),
        PortalDestination(icon: Icons.account_circle, label: 'Account'),
        PortalDestination(icon: Icons.settings, label: 'Settings'),
      ],
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      onRefresh: _loadStudentLearning,
      onSignOut: widget.authViewModel.signOut,
      body: pages[_selectedIndex],
    );
  }

  Future<void> _scanAttendanceQr() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudentQrAttendanceScreen()),
    );
    await _loadStudentLearning();
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
            gamification: snapshot?.gamification,
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
                onTap: () => onNavigate(4),
              ),
              PortalMetricCard(
                label: 'Unread',
                value: unreadCount.toString(),
                icon: Icons.notifications,
                accentColor: AppColors.warning,
                onTap: () => onNavigate(7),
              ),
              PortalMetricCard(
                label: 'Balance',
                value: _formatMoney(
                  financialSummary?.remainingBalanceMinor ?? 0,
                  financialSummary?.currency ?? 'EGP',
                ),
                icon: Icons.receipt_long,
                accentColor: AppColors.error,
                onTap: () => onNavigate(8),
              ),
            ],
          ),
          if ((snapshot?.metrics ?? const []).isNotEmpty) ...[
            const SizedBox(height: 18),
            _MetricGrid(metrics: snapshot?.metrics ?? const []),
          ],
          if (snapshot != null) ...[
            const SizedBox(height: 18),
            _GamificationPanel(summary: snapshot!.gamification),
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
    final lessonsByPath = <String, List<StudyLessonSummary>>{};
    for (final lesson in lessons) {
      lessonsByPath.putIfAbsent(lesson.pathName, () => []).add(lesson);
    }

    return PortalPageShell(
      title: 'My Lessons',
      subtitle: 'Published learning paths assigned to your active groups.',
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
        child: ListView(
          children: lessonsByPath.entries.map((entry) {
            final pathLessons = entry.value;
            final completeCount = pathLessons
                .where((lesson) => lesson.progressPercentage >= 100)
                .length;
            final progress = pathLessons.isEmpty
                ? 0.0
                : completeCount / pathLessons.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ExpansionTile(
                  initiallyExpanded: true,
                  leading: const Icon(Icons.route),
                  title: Text(entry.key),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 6),
                      Text('$completeCount/${pathLessons.length} completed'),
                    ],
                  ),
                  children: pathLessons
                      .map(
                        (lesson) => Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: PortalListCard(
                            icon: Icons.play_circle_outline,
                            accentColor: lesson.progressPercentage >= 100
                                ? AppColors.success
                                : AppColors.studentRole,
                            title: lesson.title,
                            subtitle:
                                '${lesson.unitName} | ${lesson.estimatedMinutes} min | ${lesson.progressPercentage}% complete',
                            trailing: [
                              if (lesson.hasPdf)
                                const Icon(
                                  Icons.picture_as_pdf,
                                  color: AppColors.error,
                                ),
                              if (lesson.hasCodePlayground)
                                const Icon(
                                  Icons.terminal,
                                  color: AppColors.success,
                                ),
                              IconButton(
                                tooltip: 'Open lesson',
                                onPressed: () => onOpenLesson(lesson),
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _StudentAssessmentsPage extends StatelessWidget {
  final bool isLoading;
  final List<_StudentHomeworkItem> homeworkItems;
  final List<_StudentExamItem> examItems;
  final ValueChanged<_StudentHomeworkItem> onSubmitHomework;
  final ValueChanged<_StudentExamItem> onStartExam;

  const _StudentAssessmentsPage({
    required this.isLoading,
    required this.homeworkItems,
    required this.examItems,
    required this.onSubmitHomework,
    required this.onStartExam,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = homeworkItems.isEmpty && examItems.isEmpty;
    return PortalPageShell(
      title: 'Assessments',
      subtitle: 'Homework submissions and exam entry for your active groups.',
      icon: Icons.assignment,
      accentColor: AppColors.studentRole,
      child: PortalStateView(
        isLoading: isLoading,
        errorMessage: null,
        isEmpty: isEmpty,
        emptyTitle: 'No assessments available',
        emptySubtitle: 'Published homework and exams will appear here.',
        emptyIcon: Icons.assignment_outlined,
        onRetry: () {},
        child: ListView(
          children: [
            const PortalSectionTitle(title: 'Homework'),
            const SizedBox(height: 10),
            if (homeworkItems.isEmpty)
              const _InlineEmptyState(
                icon: Icons.assignment_outlined,
                text: 'No homework assigned.',
              )
            else
              ...homeworkItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PortalListCard(
                    icon: Icons.assignment,
                    accentColor: item.isSubmitted
                        ? AppColors.success
                        : AppColors.warning,
                    title: item.homework.title,
                    subtitle:
                        '${item.groupName} | Due ${_formatDate(item.homework.dueAt)} | Max ${item.homework.maxScore.toStringAsFixed(0)}',
                    trailing: [
                      PortalStatusChip(
                        status: item.submissionStatus ?? 'pending',
                      ),
                      if (!item.isGraded)
                        IconButton(
                          tooltip: 'Submit homework',
                          onPressed: () => onSubmitHomework(item),
                          icon: const Icon(Icons.upload_file),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            const PortalSectionTitle(title: 'Exams'),
            const SizedBox(height: 10),
            if (examItems.isEmpty)
              const _InlineEmptyState(
                icon: Icons.quiz_outlined,
                text: 'No published exams.',
              )
            else
              ...examItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PortalListCard(
                    icon: Icons.quiz,
                    accentColor: item.canStart
                        ? AppColors.studentRole
                        : AppColors.info,
                    title: item.exam.title,
                    subtitle:
                        '${item.groupName} | ${item.exam.durationMinutes} min | Attempts ${item.attemptCount}/${item.exam.maxAttempts}',
                    trailing: [
                      PortalStatusChip(
                        status: item.lastAttemptStatus ?? item.exam.status,
                      ),
                      IconButton(
                        tooltip: item.canStart
                            ? 'Start exam'
                            : 'Maximum attempts reached',
                        onPressed: item.canStart
                            ? () => onStartExam(item)
                            : null,
                        icon: const Icon(Icons.play_arrow),
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

class _StudentHomeworkItem {
  final Homework homework;
  final String groupName;
  final String? submissionStatus;
  final double? submissionScore;
  final String? teacherFeedback;
  final DateTime? submittedAt;

  const _StudentHomeworkItem({
    required this.homework,
    required this.groupName,
    this.submissionStatus,
    this.submissionScore,
    this.teacherFeedback,
    this.submittedAt,
  });

  bool get isSubmitted =>
      submissionStatus == 'submitted' || submissionStatus == 'graded';
  bool get isGraded => submissionStatus == 'graded';

  factory _StudentHomeworkItem.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _StudentHomeworkItem(
      homework: Homework.fromJson(json),
      groupName: json['group_name'] as String? ?? 'Group',
      submissionStatus: json['submission_status'] as String?,
      submissionScore: (json['submission_score'] as num?)?.toDouble(),
      teacherFeedback: json['teacher_feedback'] as String?,
      submittedAt: json['submitted_at'] == null
          ? null
          : DateTime.tryParse(json['submitted_at'].toString()),
    );
  }
}

class _StudentExamItem {
  final Exam exam;
  final String groupName;
  final int attemptCount;
  final String? lastAttemptStatus;
  final double? lastScore;

  const _StudentExamItem({
    required this.exam,
    required this.groupName,
    required this.attemptCount,
    this.lastAttemptStatus,
    this.lastScore,
  });

  bool get canStart => attemptCount < exam.maxAttempts;

  factory _StudentExamItem.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _StudentExamItem(
      exam: Exam.fromJson(json),
      groupName: json['group_name'] as String? ?? 'Group',
      attemptCount: json['attempt_count'] as int? ?? 0,
      lastAttemptStatus: json['last_attempt_status'] as String?,
      lastScore: (json['last_score'] as num?)?.toDouble(),
    );
  }
}

class _StudentAttendancePage extends StatelessWidget {
  final bool isLoading;
  final List<_StudentAttendanceItem> attendanceItems;
  final List<_StudentLeaveItem> leaveItems;
  final VoidCallback onCreateLeaveRequest;
  final VoidCallback onScanQr;

  const _StudentAttendancePage({
    required this.isLoading,
    required this.attendanceItems,
    required this.leaveItems,
    required this.onCreateLeaveRequest,
    required this.onScanQr,
  });

  @override
  Widget build(BuildContext context) {
    final total = attendanceItems.length;
    final present = attendanceItems
        .where((item) => item.status == 'present')
        .length;
    final late = attendanceItems.where((item) => item.status == 'late').length;
    final absent = attendanceItems
        .where((item) => item.status == 'absent')
        .length;
    final excused = attendanceItems
        .where((item) => item.status == 'excused')
        .length;
    final percentage = total == 0
        ? 100
        : (((present + late + excused) / total) * 100).round();

    return PortalPageShell(
      title: 'Attendance',
      subtitle: 'Your session attendance history and leave requests.',
      icon: Icons.event_available,
      accentColor: AppColors.studentRole,
      actions: [
        PortalAction(
          icon: Icons.qr_code_scanner,
          label: 'Scan QR',
          onPressed: onScanQr,
          primary: true,
        ),
        PortalAction(
          icon: Icons.event_busy,
          label: 'Request Leave',
          onPressed: onCreateLeaveRequest,
        ),
      ],
      child: PortalStateView(
        isLoading: isLoading,
        errorMessage: null,
        isEmpty: false,
        emptyTitle: 'No attendance records',
        emptySubtitle: 'Attendance appears after sessions are marked.',
        emptyIcon: Icons.event_available,
        onRetry: () {},
        child: ListView(
          children: [
            PortalMetricGrid(
              children: [
                PortalMetricCard(
                  label: 'Attendance',
                  value: '$percentage%',
                  icon: Icons.insights,
                  accentColor: AppColors.studentRole,
                ),
                PortalMetricCard(
                  label: 'Present',
                  value: present.toString(),
                  icon: Icons.check_circle,
                  accentColor: AppColors.success,
                ),
                PortalMetricCard(
                  label: 'Late',
                  value: late.toString(),
                  icon: Icons.schedule,
                  accentColor: AppColors.warning,
                ),
                PortalMetricCard(
                  label: 'Absent',
                  value: absent.toString(),
                  icon: Icons.cancel,
                  accentColor: AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const PortalSectionTitle(title: 'History'),
            const SizedBox(height: 10),
            if (attendanceItems.isEmpty)
              const _InlineEmptyState(
                icon: Icons.event_available,
                text: 'No marked sessions yet.',
              )
            else
              ...attendanceItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PortalListCard(
                    icon: _attendanceIcon(item.status),
                    accentColor: _attendanceColor(item.status),
                    title:
                        '${_formatDate(item.sessionDate)} - ${item.groupName}',
                    subtitle:
                        '${_formatTime(item.scheduledStartAt)} - ${_formatTime(item.scheduledEndAt)}${item.notes == null ? "" : " | ${item.notes}"}',
                    trailing: [PortalStatusChip(status: item.status)],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            PortalSectionTitle(
              title: 'Leave Requests',
              subtitle: '$excused excused session${excused == 1 ? "" : "s"}',
            ),
            const SizedBox(height: 10),
            if (leaveItems.isEmpty)
              const _InlineEmptyState(
                icon: Icons.event_busy,
                text: 'No leave requests submitted.',
              )
            else
              ...leaveItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PortalListCard(
                    icon: Icons.event_busy,
                    accentColor: _leaveColor(item.status),
                    title: item.classSessionId == null
                        ? 'General leave request'
                        : '${_formatDate(item.sessionDate ?? item.submittedAt)} - ${item.groupName}',
                    subtitle:
                        '${item.reason} | Submitted ${_formatDate(item.submittedAt)}${item.reviewerNote == null ? "" : " | ${item.reviewerNote}"}',
                    trailing: [PortalStatusChip(status: item.status)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StudentAttendanceItem {
  final String id;
  final String classSessionId;
  final String status;
  final DateTime markedAt;
  final DateTime sessionDate;
  final DateTime scheduledStartAt;
  final DateTime scheduledEndAt;
  final String groupName;
  final String? notes;

  const _StudentAttendanceItem({
    required this.id,
    required this.classSessionId,
    required this.status,
    required this.markedAt,
    required this.sessionDate,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
    required this.groupName,
    this.notes,
  });

  factory _StudentAttendanceItem.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    final groupName = [
      json['group_name'] as String? ?? 'Group',
      json['group_code'] as String? ?? '',
    ].where((part) => part.trim().isNotEmpty).join(' ');
    return _StudentAttendanceItem(
      id: json['id'] as String? ?? '',
      classSessionId: json['class_session_id'] as String? ?? '',
      status: json['attendance_status'] as String? ?? 'present',
      markedAt:
          DateTime.tryParse(json['marked_at']?.toString() ?? '') ??
          DateTime.now(),
      sessionDate:
          DateTime.tryParse(json['session_date']?.toString() ?? '') ??
          DateTime.now(),
      scheduledStartAt:
          DateTime.tryParse(json['scheduled_start_at']?.toString() ?? '') ??
          DateTime.now(),
      scheduledEndAt:
          DateTime.tryParse(json['scheduled_end_at']?.toString() ?? '') ??
          DateTime.now(),
      groupName: groupName,
      notes: json['notes'] as String?,
    );
  }
}

class _StudentLeaveItem {
  final String id;
  final String? classSessionId;
  final String reason;
  final String status;
  final DateTime submittedAt;
  final String? reviewerNote;
  final DateTime? sessionDate;
  final String groupName;

  const _StudentLeaveItem({
    required this.id,
    this.classSessionId,
    required this.reason,
    required this.status,
    required this.submittedAt,
    this.reviewerNote,
    this.sessionDate,
    required this.groupName,
  });

  factory _StudentLeaveItem.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _StudentLeaveItem(
      id: json['id'] as String? ?? '',
      classSessionId: json['class_session_id'] as String?,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      submittedAt:
          DateTime.tryParse(json['submitted_at']?.toString() ?? '') ??
          DateTime.now(),
      reviewerNote: json['reviewer_note'] as String?,
      sessionDate: DateTime.tryParse(json['session_date']?.toString() ?? ''),
      groupName: json['group_name'] as String? ?? 'General',
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

class _StudentSessionBoardsPage extends StatelessWidget {
  final bool isLoading;
  final List<_PublishedSessionBoard> boards;
  final ValueChanged<_PublishedSessionBoard> onOpenBoard;

  const _StudentSessionBoardsPage({
    required this.isLoading,
    required this.boards,
    required this.onOpenBoard,
  });

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'Session Boards',
      subtitle: 'Published class boards from sessions you attended.',
      icon: Icons.draw,
      accentColor: AppColors.studentRole,
      child: PortalStateView(
        isLoading: isLoading,
        errorMessage: null,
        isEmpty: boards.isEmpty,
        emptyTitle: 'No published boards',
        emptySubtitle:
            'Boards appear here after your teacher publishes a board for an attended session.',
        emptyIcon: Icons.draw_outlined,
        onRetry: () {},
        child: ListView.separated(
          itemCount: boards.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final board = boards[index];
            return PortalListCard(
              icon: Icons.draw,
              accentColor: AppColors.studentRole,
              title: board.title,
              subtitle:
                  '${board.groupName} | ${_formatDate(board.sessionDate)} | Updated ${_formatDate(board.updatedAt)}',
              trailing: [
                IconButton(
                  tooltip: 'Open board',
                  onPressed: () => onOpenBoard(board),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
              onTap: () => onOpenBoard(board),
            );
          },
        ),
      ),
    );
  }
}

class _StudentSessionBoardScreen extends StatelessWidget {
  final _PublishedSessionBoard board;

  const _StudentSessionBoardScreen({required this.board});

  @override
  Widget build(BuildContext context) {
    final strokes = _decodeSessionBoard(board.boardData);
    return Scaffold(
      appBar: AppBar(title: Text(board.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeaderPill(icon: Icons.group_work, label: board.groupName),
                _HeaderPill(
                  icon: Icons.event,
                  label: _formatDate(board.sessionDate),
                ),
                _HeaderPill(
                  icon: Icons.update,
                  label: 'Updated ${_formatDate(board.updatedAt)}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomPaint(
                    painter: _SessionBoardPainter(strokes),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _PublishedSessionBoard {
  final String id;
  final String title;
  final String groupName;
  final DateTime sessionDate;
  final DateTime updatedAt;
  final Map<String, dynamic> boardData;

  const _PublishedSessionBoard({
    required this.id,
    required this.title,
    required this.groupName,
    required this.sessionDate,
    required this.updatedAt,
    required this.boardData,
  });

  factory _PublishedSessionBoard.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    final sessionTitle = json['title'] as String?;
    final groupName = json['group_name'] as String? ?? 'Group';

    return _PublishedSessionBoard(
      id: json['id'] as String? ?? '',
      title: sessionTitle == null || sessionTitle.trim().isEmpty
          ? 'Published session board'
          : sessionTitle,
      groupName: groupName,
      sessionDate:
          DateTime.tryParse(json['session_date']?.toString() ?? '') ??
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      boardData: Map<String, dynamic>.from(json['board_data'] as Map? ?? {}),
    );
  }
}

class _SessionBoardStroke {
  final Color color;
  final double width;
  final List<Offset> points;

  const _SessionBoardStroke({
    required this.color,
    required this.width,
    required this.points,
  });

  static _SessionBoardStroke fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? [];
    return _SessionBoardStroke(
      color: Color(json['color'] as int? ?? 0xFF111827),
      width: (json['width'] as num? ?? 4).toDouble(),
      points: rawPoints.map((p) {
        final point = Map<String, dynamic>.from(p as Map);
        return Offset(
          (point['x'] as num? ?? 0).toDouble(),
          (point['y'] as num? ?? 0).toDouble(),
        );
      }).toList(),
    );
  }
}

class _SessionBoardPainter extends CustomPainter {
  final List<_SessionBoardStroke> strokes;

  const _SessionBoardPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (var y = 28.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SessionBoardPainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}

List<_SessionBoardStroke> _decodeSessionBoard(Map<String, dynamic> data) {
  try {
    final rawStrokes = data['strokes'] as List<dynamic>? ?? [];
    return rawStrokes
        .map(
          (stroke) => _SessionBoardStroke.fromJson(
            Map<String, dynamic>.from(stroke as Map),
          ),
        )
        .toList();
  } catch (_) {
    return [];
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
            Expanded(child: Text(context.l10n.t(text))),
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
            Expanded(child: Text(context.l10n.t(text))),
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

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

IconData _attendanceIcon(String status) {
  switch (status) {
    case 'absent':
      return Icons.cancel;
    case 'late':
      return Icons.schedule;
    case 'excused':
      return Icons.event_available;
    case 'present':
    default:
      return Icons.check_circle;
  }
}

Color _attendanceColor(String status) {
  switch (status) {
    case 'absent':
      return AppColors.error;
    case 'late':
      return AppColors.warning;
    case 'excused':
      return AppColors.info;
    case 'present':
    default:
      return AppColors.success;
  }
}

Color _leaveColor(String status) {
  switch (status) {
    case 'approved':
      return AppColors.success;
    case 'rejected':
      return AppColors.error;
    case 'cancelled':
      return AppColors.info;
    case 'pending':
    default:
      return AppColors.warning;
  }
}

class _HeroPanel extends StatelessWidget {
  final String studentName;
  final bool isLoading;
  final StudyLessonSummary? lesson;
  final StudentGamificationSummary? gamification;
  final VoidCallback? onOpenWorkspace;

  const _HeroPanel({
    required this.studentName,
    required this.isLoading,
    required this.lesson,
    required this.gamification,
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
              Text(
                context.tr(
                  'Your learning workspace opens only from published lessons assigned to your active groups.',
                ),
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
                  context.tr(
                    onOpenWorkspace == null
                        ? 'No lesson ready'
                        : 'Resume lesson',
                  ),
                ),
              ),
            ],
          );
          final progress = _HeroProgressCard(
            isLoading: isLoading,
            lesson: lesson,
            gamification: gamification,
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
  final StudentGamificationSummary? gamification;

  const _HeroProgressCard({
    required this.isLoading,
    required this.lesson,
    required this.gamification,
  });

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
            Text(
              context.tr('No published lesson is available.'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Enroll the student and publish curriculum content to start.',
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ] else ...[
            if (gamification != null) ...[
              Text(
                'Level ${gamification!.level} | ${gamification!.totalXp} XP',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: gamification!.levelProgressPercentage / 100,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                '${gamification!.xpToNextLevel} XP to next level | ${gamification!.streakDays}d streak',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 14),
            ],
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

class _GamificationPanel extends StatelessWidget {
  final StudentGamificationSummary summary;

  const _GamificationPanel({required this.summary});

  @override
  Widget build(BuildContext context) {
    final badges = summary.badges.take(4).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PortalSectionTitle(
              title: 'Learning progress',
              subtitle: 'XP is awarded from real completed lessons.',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.studentRole.withValues(alpha: .12),
                  foregroundColor: AppColors.studentRole,
                  child: Text(
                    summary.level.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.totalXp} XP',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: summary.levelProgressPercentage / 100,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${summary.xpToNextLevel} XP to level ${summary.level + 1}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FeaturePill(
                  icon: Icons.local_fire_department,
                  label: '${summary.streakDays}d streak',
                ),
                _FeaturePill(
                  icon: Icons.workspace_premium,
                  label: '${summary.badgeCount} badges',
                ),
                for (final badge in badges)
                  _FeaturePill(icon: Icons.military_tech, label: badge),
              ],
            ),
          ],
        ),
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
                    ? context.tr(
                        'You are enrolled, but no published lessons are available yet.',
                      )
                    : context.tr(
                        'You are not enrolled in any active group yet.',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
