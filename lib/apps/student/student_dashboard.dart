import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/di/injection.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/supabase_client_wrapper.dart';
import '../../design_system/tokens/colors.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import 'screens/student_group_details_screen.dart';
import '../../features/assessment/data/repositories/supabase_assessment_repositories.dart';
import '../../features/assessment/presentation/screens/assessment_screens.dart';
import '../../features/attendance/presentation/screens/student_qr_attendance_screen.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/communication/data/repositories/supabase_announcement_repository.dart';
import '../../features/communication/data/repositories/supabase_notification_repository.dart';
import '../../features/communication/domain/repositories/i_notification_repository.dart';
import '../../features/communication/domain/models/announcement.dart';
import '../../features/communication/domain/models/notification.dart';
import '../../features/communication/presentation/screens/notification_center_screen.dart';
import '../../features/communication/presentation/viewmodels/notification_center_viewmodel.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../features/payments/data/repositories/supabase_payment_repositories.dart';
import '../../features/payments/domain/models/payment_models.dart';
import '../../features/study_workspace/data/repositories/supabase_student_learning_repository.dart';
import '../../features/study_workspace/data/repositories/supabase_study_workspace_repository.dart';
import '../../features/study_workspace/domain/models/study_workspace_models.dart';
import '../../features/study_workspace/presentation/screens/study_workspace_screen.dart';

import 'student_dashboard_models.dart';
import 'tabs/home_tab.dart';
import 'tabs/learn_tab.dart';
import 'tabs/activity_tab.dart';
import 'tabs/account_tab.dart';

class StudentDashboard extends StatefulWidget {
  final AuthViewModel authViewModel;

  const StudentDashboard({super.key, required this.authViewModel});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 0;

  // ── data state ──
  bool _isLoading = false;
  String? _loadError;
  List<GroupEntity> _enrolledGroups = [];
  StudentLearningSnapshot? _snapshot;
  FinancialSummary? _financialSummary;
  List<Invoice> _invoices = [];
  List<Receipt> _receipts = [];
  List<Announcement> _announcements = [];
  List<AppNotification> _notifications = [];
  List<PublishedSessionBoard> _sessionBoards = [];
  List<StudentHomeworkItem> _homeworkItems = [];
  List<StudentExamItem> _examItems = [];
  List<StudentAttendanceItem> _attendanceItems = [];
  List<StudentLeaveItem> _leaveItems = [];
  int _unreadCount = 0;
  StreamSubscription<AppNotification>? _notificationSubscription;
  late final NotificationCenterViewModel _notificationCenterViewModel;

  @override
  void initState() {
    super.initState();
    _notificationCenterViewModel = NotificationCenterViewModel(
      getIt<INotificationRepository>(),
    );
    _notificationCenterViewModel.addListener(_syncNotificationCenterState);
    _subscribeToNotifications();
    _loadAll();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _notificationCenterViewModel.removeListener(_syncNotificationCenterState);
    _notificationCenterViewModel.dispose();
    super.dispose();
  }

  void _syncNotificationCenterState() {
    if (!mounted) return;
    setState(() {
      _notifications = _notificationCenterViewModel.notifications;
      _unreadCount = _notificationCenterViewModel.unreadCount;
    });
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

  // ── data loading ──

  Future<void> _loadAll() async {
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
      final notificationRepo = getIt<INotificationRepository>();
      final results = await Future.wait([
        SupabaseEnrollmentRepository(wrapper).fetchGroupsForStudent(studentId),
        SupabaseStudentLearningRepository(
          wrapper,
        ).fetchSnapshotForStudent(studentId),
        SupabasePaymentRepository(
          wrapper,
        ).fetchStudentFinancialSummary(studentId),
        SupabaseInvoiceRepository(wrapper).fetchInvoicesForStudent(studentId),
        SupabaseReceiptRepository(wrapper).fetchReceiptsForStudent(studentId),
        SupabaseAnnouncementRepository(wrapper).getTargetedAnnouncements(),
        notificationRepo.getNotifications(),
        notificationRepo.getUnreadCount(),
        _fetchSessionBoards(),
        _fetchHomeworkFeed(),
        _fetchExamFeed(),
        _fetchAttendanceHistory(),
        _fetchLeaveRequests(),
      ]);

      if (!mounted) return;
      setState(() {
        _enrolledGroups = results[0] as List<GroupEntity>;
        _snapshot = results[1] as StudentLearningSnapshot;
        _financialSummary = results[2] as FinancialSummary;
        _invoices = results[3] as List<Invoice>;
        _receipts = results[4] as List<Receipt>;
        _announcements = results[5] as List<Announcement>;
        _notifications = results[6] as List<AppNotification>;
        _unreadCount = results[7] as int;
        _sessionBoards = results[8] as List<PublishedSessionBoard>;
        _homeworkItems = results[9] as List<StudentHomeworkItem>;
        _examItems = results[10] as List<StudentExamItem>;
        _attendanceItems = results[11] as List<StudentAttendanceItem>;
        _leaveItems = results[12] as List<StudentLeaveItem>;
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

  Future<List<StudentHomeworkItem>> _fetchHomeworkFeed() async {
    try {
      final rows = await Supabase.instance.client.rpc(
        'get_student_homework_feed',
      );
      return (rows as List)
          .whereType<Map>()
          .map((r) => StudentHomeworkItem.fromJson(r))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<StudentExamItem>> _fetchExamFeed() async {
    try {
      final rows = await Supabase.instance.client.rpc('get_student_exam_feed');
      return (rows as List)
          .whereType<Map>()
          .map((r) => StudentExamItem.fromJson(r))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<StudentAttendanceItem>> _fetchAttendanceHistory() async {
    try {
      final rows = await Supabase.instance.client.rpc(
        'get_current_student_attendance_history',
        params: {'p_limit': 120},
      );
      return (rows as List)
          .whereType<Map>()
          .map((r) => StudentAttendanceItem.fromJson(r))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<StudentLeaveItem>> _fetchLeaveRequests() async {
    try {
      final rows = await Supabase.instance.client.rpc(
        'get_current_student_leave_requests',
      );
      return (rows as List)
          .whereType<Map>()
          .map((r) => StudentLeaveItem.fromJson(r))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PublishedSessionBoard>> _fetchSessionBoards() async {
    try {
      final rows = await Supabase.instance.client.rpc(
        'get_student_published_session_boards',
      );
      return (rows as List)
          .whereType<Map>()
          .map((r) => PublishedSessionBoard.fromJson(r))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── actions ──

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

  void _openSessionBoard(PublishedSessionBoard board) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _SessionBoardScreen(board: board)),
    );
  }

  Future<void> _openGroupDetails(GroupEntity group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentGroupDetailsScreen(
          group: group,
          studentId: widget.authViewModel.bootstrap?.studentId,
        ),
      ),
    );
    await _loadAll();
  }

  Future<void> _scanAttendanceQr() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudentQrAttendanceScreen()),
    );
    await _loadAll();
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
                  isExpanded: true,
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
                          '${DateFormat.yMMMd().format(item.sessionDate)} - ${item.groupName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedSessionId = v),
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
      await _loadAll();
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

  Future<void> _submitHomework(StudentHomeworkItem item) async {
    final textCtrl = TextEditingController();
    final attachCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Submit ${item.homework.title}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Answer / notes'),
                  alignLabelWithHint: true,
                ),
                minLines: 4,
                maxLines: 8,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: attachCtrl,
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
      textCtrl.dispose();
      attachCtrl.dispose();
      return;
    }
    try {
      await Supabase.instance.client.rpc(
        'submit_homework_text',
        params: {
          'p_homework_id': item.homework.id,
          'p_submission_text': textCtrl.text.trim(),
          'p_attachment_url': attachCtrl.text.trim().isEmpty
              ? null
              : attachCtrl.text.trim(),
        },
      );
      await _loadAll();
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
      textCtrl.dispose();
      attachCtrl.dispose();
    }
  }

  Future<void> _startExam(StudentExamItem item) async {
    final groupId = item.exam.groupId;
    if (groupId == null) return;
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final repo = SupabaseExamRepository(wrapper);
      final exams = await repo.fetchExamsForGroup(groupId);
      final exam = exams.firstWhere((e) => e.id == item.exam.id);
      final attempt = await repo.startExam(exam.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExamRunnerScreen(
            exam: exam,
            attempt: attempt,
            onOptionSelected: (qId, oId) => repo.saveExamAnswer(
              attemptId: attempt.id,
              questionId: qId,
              selectedOptionId: oId,
            ),
            onSubmit: () async {
              await repo.submitExamAttempt(attempt.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),
      );
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exam failed: $e')));
    }
  }

  Future<void> _markNotificationRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      await SupabaseNotificationRepository(wrapper).markRead(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((n) => n.id == notification.id ? n.copyWith(isRead: true) : n)
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

  void _openNotification(AppNotification notification) {
    unawaited(_markNotificationRead(notification));
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    final pushService = getIt.isRegistered<PushNotificationService>()
        ? getIt<PushNotificationService>()
        : PushNotificationService(wrapper);
    pushService.handleNotificationTap({
      'type': notification.type,
      'reference_id': notification.referenceId,
      'id': notification.id,
      'title': notification.title,
      'message': notification.message,
    });
  }

  Future<void> _markAllNotificationsRead() async {
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      await SupabaseNotificationRepository(wrapper).markAllRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
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
              (a) => a.id == announcement.id
                  ? a.copyWith(
                      readAt: DateTime.now(),
                      acknowledgedAt: DateTime.now(),
                    )
                  : a,
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

  // ── build ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final user = widget.authViewModel.currentUser;
    final nextLesson = _snapshot?.nextLesson;

    final tabs = [
      HomeTab(
        userName: user?.fullName ?? 'Student',
        isLoading: _isLoading,
        errorMessage: _loadError,
        snapshot: _snapshot,
        enrolledGroups: _enrolledGroups,
        financialSummary: _financialSummary,
        unreadCount: _unreadCount,
        pendingHomework: _homeworkItems.where((h) => !h.isSubmitted).toList(),
        onRetry: _loadAll,
        onOpenWorkspace: nextLesson == null
            ? null
            : () => _openWorkspace(nextLesson),
        onNavigate: (i) => setState(() => _selectedIndex = i),
      ),
      LearnTab(
        isLoading: _isLoading,
        lessons: _snapshot?.availableLessons ?? const [],
        groups: _enrolledGroups,
        onOpenLesson: _openWorkspace,
        onOpenGroup: _openGroupDetails,
      ),
      ActivityTab(
        isLoading: _isLoading,
        homeworkItems: _homeworkItems,
        examItems: _examItems,
        attendanceItems: _attendanceItems,
        leaveItems: _leaveItems,
        sessionBoards: _sessionBoards,
        onSubmitHomework: _submitHomework,
        onStartExam: _startExam,
        onCreateLeaveRequest: _createLeaveRequest,
        onScanQr: _scanAttendanceQr,
        onOpenBoard: _openSessionBoard,
      ),
      NotificationCenterScreen(viewModel: _notificationCenterViewModel),
      AccountTab(
        profile: user,
        role: widget.authViewModel.userRole?.displayName ?? 'Student',
        studentId: widget.authViewModel.bootstrap?.studentId,
        financialSummary: _financialSummary,
        invoices: _invoices,
        receipts: _receipts,
        announcements: _announcements,
        notifications: _notifications,
        unreadCount: _unreadCount,
        isLoading: _isLoading,
        onSignOut: widget.authViewModel.signOut,
        onProfileChanged: widget.authViewModel.restoreSession,
        onNotificationTap: _openNotification,
        onMarkAllRead: _markAllNotificationsRead,
        onAcknowledge: _acknowledgeAnnouncement,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        final body = SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _loadAll,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: tabs[_selectedIndex],
            ),
          ),
        );

        if (isWide) {
          return Scaffold(
            backgroundColor: bgColor,
            body: Row(
              children: [
                NavigationRail(
                  backgroundColor: surfaceColor,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                  labelType: NavigationRailLabelType.all,
                  indicatorColor: AppColors.primary.withValues(alpha: 0.12),
                  selectedIconTheme: const IconThemeData(
                    color: AppColors.primary,
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.house_outlined),
                      selectedIcon: const Icon(Icons.house_rounded),
                      label: Text(context.tr('Home')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.menu_book_outlined),
                      selectedIcon: const Icon(Icons.menu_book_rounded),
                      label: Text(context.tr('Learn')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.bolt_outlined),
                      selectedIcon: const Icon(Icons.bolt_rounded),
                      label: Text(context.tr('Activity')),
                    ),
                    NavigationRailDestination(
                      icon: Badge(
                        isLabelVisible: _unreadCount > 0,
                        label: Text(_unreadCount > 9 ? '9+' : '$_unreadCount'),
                        child: const Icon(Icons.notifications_none_rounded),
                      ),
                      selectedIcon: const Icon(Icons.notifications_rounded),
                      label: Text(context.tr('Notifications')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.person_outline_rounded),
                      selectedIcon: const Icon(Icons.person_rounded),
                      label: Text(context.tr('Account')),
                    ),
                  ],
                ),
                VerticalDivider(thickness: 1, width: 1, color: borderColor),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: bgColor,
          body: body,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: borderColor, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                indicatorColor: AppColors.primary.withValues(alpha: 0.12),
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) =>
                    setState(() => _selectedIndex = i),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.house_outlined),
                    selectedIcon: const Icon(
                      Icons.house_rounded,
                      color: AppColors.primary,
                    ),
                    label: context.tr('Home'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.menu_book_outlined),
                    selectedIcon: const Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.primary,
                    ),
                    label: context.tr('Learn'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.bolt_outlined),
                    selectedIcon: const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.primary,
                    ),
                    label: context.tr('Activity'),
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: _unreadCount > 0,
                      label: Text(_unreadCount > 9 ? '9+' : '$_unreadCount'),
                      child: const Icon(Icons.notifications_none_rounded),
                    ),
                    selectedIcon: const Icon(
                      Icons.notifications_rounded,
                      color: AppColors.primary,
                    ),
                    label: context.tr('Notifications'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline_rounded),
                    selectedIcon: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                    ),
                    label: context.tr('Account'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Session Board screen ──

class _SessionBoardScreen extends StatefulWidget {
  final PublishedSessionBoard board;
  const _SessionBoardScreen({required this.board});

  @override
  State<_SessionBoardScreen> createState() => _SessionBoardScreenState();
}

class _SessionBoardScreenState extends State<_SessionBoardScreen> {
  final List<BoardStroke> _studentStrokes = [];
  BoardStroke? _activeStroke;
  bool _isDrawingMode = false;
  bool _eraser = false;
  final Color _selectedColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadStrokes();
  }

  Future<void> _loadStrokes() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'board_${widget.board.id}_strokes';
    final data = prefs.getStringList(key);
    if (data != null) {
      setState(() {
        _studentStrokes.clear();
        for (final item in data) {
          try {
            _studentStrokes.add(BoardStroke.fromJson(jsonDecode(item)));
          } catch (_) {}
        }
      });
    }
  }

  Future<void> _saveStrokes() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'board_${widget.board.id}_strokes';
    final data = _studentStrokes.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(key, data);
  }

  void _startStroke(DragStartDetails details) {
    if (!_isDrawingMode) return;
    setState(() {
      _activeStroke = BoardStroke(
        color: _eraser ? Colors.white : _selectedColor,
        width: _eraser ? 22 : 4,
        points: [details.localPosition],
      );
    });
  }

  void _appendStroke(DragUpdateDetails details) {
    if (!_isDrawingMode) return;
    final stroke = _activeStroke;
    if (stroke == null) return;
    setState(() {
      _activeStroke = BoardStroke(
        color: stroke.color,
        width: stroke.width,
        points: [...stroke.points, details.localPosition],
      );
    });
  }

  void _endStroke([DragEndDetails? _]) {
    if (!_isDrawingMode) return;
    final stroke = _activeStroke;
    if (stroke != null && stroke.points.length > 1) {
      setState(() => _studentStrokes.add(stroke));
      _saveStrokes();
    }
    setState(() => _activeStroke = null);
  }

  @override
  Widget build(BuildContext context) {
    final teacherStrokes = decodeSessionBoard(widget.board.boardData);
    final allStrokes = [
      ...teacherStrokes,
      ..._studentStrokes,
      if (_activeStroke != null) _activeStroke!,
    ];

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(widget.board.title),
        actions: [
          IconButton(
            icon: Icon(_isDrawingMode ? Icons.pan_tool : Icons.edit),
            tooltip: _isDrawingMode
                ? context.tr('Switch to Pan/Zoom')
                : context.tr('Switch to Draw'),
            onPressed: () => setState(() => _isDrawingMode = !_isDrawingMode),
          ),
          if (_isDrawingMode) ...[
            IconButton(
              icon: Icon(_eraser ? Icons.edit : Icons.auto_fix_high),
              tooltip: context.tr('Toggle Eraser'),
              onPressed: () => setState(() => _eraser = !_eraser),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: context.tr('Clear my drawing'),
              onPressed: () {
                setState(() => _studentStrokes.clear());
                _saveStrokes();
              },
            ),
          ],
        ],
      ),
      body: InteractiveViewer(
        panEnabled: !_isDrawingMode,
        scaleEnabled: true,
        minScale: 0.1,
        maxScale: 5.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: GestureDetector(
          onPanStart: _isDrawingMode ? _startStroke : null,
          onPanUpdate: _isDrawingMode ? _appendStroke : null,
          onPanEnd: _isDrawingMode ? _endStroke : null,
          child: Container(
            color: Colors.white,
            width: double.infinity,
            height: double.infinity,
            child: CustomPaint(painter: _BoardPainter(allStrokes)),
          ),
        ),
      ),
    );
  }
}

List<BoardStroke> decodeSessionBoard(Map<String, dynamic> data) {
  final strokesData = data['strokes'] as List?;
  if (strokesData == null) return [];
  return strokesData
      .map((s) => BoardStroke.fromJson(s as Map<String, dynamic>))
      .toList();
}

class _BoardPainter extends CustomPainter {
  final List<BoardStroke> strokes;
  _BoardPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (stroke.points.isNotEmpty) {
        final path = Path()
          ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) => true;
}
