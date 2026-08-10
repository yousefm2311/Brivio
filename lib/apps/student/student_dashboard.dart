import 'dart:async';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _subscribeToNotifications();
    _loadAll();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToNotifications() {
    final notificationRepo = getIt<INotificationRepository>();
    _notificationSubscription = notificationRepo.subscribeToNotifications().listen((notification) {
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
        SupabaseStudentLearningRepository(wrapper).fetchSnapshotForStudent(studentId),
        SupabasePaymentRepository(wrapper).fetchStudentFinancialSummary(studentId),
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
    final rows = await Supabase.instance.client.rpc('get_student_homework_feed');
    return (rows as List).whereType<Map>().map((r) => StudentHomeworkItem.fromJson(r)).toList();
  }

  Future<List<StudentExamItem>> _fetchExamFeed() async {
    final rows = await Supabase.instance.client.rpc('get_student_exam_feed');
    return (rows as List).whereType<Map>().map((r) => StudentExamItem.fromJson(r)).toList();
  }

  Future<List<StudentAttendanceItem>> _fetchAttendanceHistory() async {
    final rows = await Supabase.instance.client
        .rpc('get_current_student_attendance_history', params: {'p_limit': 120});
    return (rows as List).whereType<Map>().map((r) => StudentAttendanceItem.fromJson(r)).toList();
  }

  Future<List<StudentLeaveItem>> _fetchLeaveRequests() async {
    final rows = await Supabase.instance.client.rpc('get_current_student_leave_requests');
    return (rows as List).whereType<Map>().map((r) => StudentLeaveItem.fromJson(r)).toList();
  }

  Future<List<PublishedSessionBoard>> _fetchSessionBoards() async {
    final rows = await Supabase.instance.client.rpc('get_student_published_session_boards');
    return (rows as List).whereType<Map>().map((r) => PublishedSessionBoard.fromJson(r)).toList();
  }

  // ── actions ──

  void _openWorkspace(StudyLessonSummary lesson) {
    final studentId = widget.authViewModel.bootstrap?.studentId;
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StudyWorkspaceScreen(
        lesson: lesson,
        studentId: studentId,
        repository: SupabaseStudyWorkspaceRepository(wrapper),
      ),
    ));
  }

  void _openSessionBoard(PublishedSessionBoard board) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _SessionBoardScreen(board: board),
    ));
  }

  Future<void> _openGroupDetails(GroupEntity group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentGroupDetailsScreen(group: group),
      ),
    );
    await _loadAll();
  }

  Future<void> _scanAttendanceQr() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StudentQrAttendanceScreen()));
    await _loadAll();
  }

  Future<void> _createLeaveRequest() async {
    final reasonController = TextEditingController();
    String? selectedSessionId = _attendanceItems.isEmpty ? null : _attendanceItems.first.classSessionId;

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
                  decoration: InputDecoration(labelText: context.tr('Session'), prefixIcon: const Icon(Icons.event)),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(context.tr('General leave request'))),
                    for (final item in _attendanceItems.take(30))
                      DropdownMenuItem<String?>(
                        value: item.classSessionId,
                        child: Text('${DateFormat.yMMMd().format(item.sessionDate)} - ${item.groupName}', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedSessionId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(labelText: context.tr('Reason'), alignLabelWithHint: true),
                  minLines: 3,
                  maxLines: 6,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.send),
              label: Text(context.tr('Send')),
            ),
          ],
        ),
      ),
    );

    if (submitted != true) { reasonController.dispose(); return; }

    try {
      await Supabase.instance.client.rpc('create_student_leave_request', params: {
        'p_class_session_id': selectedSessionId,
        'p_reason': reasonController.text.trim(),
      });
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Leave request sent.'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Leave request failed: $e')));
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
              TextField(controller: textCtrl, decoration: InputDecoration(labelText: context.tr('Answer / notes'), alignLabelWithHint: true), minLines: 4, maxLines: 8),
              const SizedBox(height: 12),
              TextField(controller: attachCtrl, decoration: InputDecoration(labelText: context.tr('Attachment URL'), prefixIcon: const Icon(Icons.link)), keyboardType: TextInputType.url),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.upload_file), label: Text(context.tr('Submit'))),
        ],
      ),
    );
    if (submitted != true) { textCtrl.dispose(); attachCtrl.dispose(); return; }
    try {
      await Supabase.instance.client.rpc('submit_homework_text', params: {
        'p_homework_id': item.homework.id,
        'p_submission_text': textCtrl.text.trim(),
        'p_attachment_url': attachCtrl.text.trim().isEmpty ? null : attachCtrl.text.trim(),
      });
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Homework submitted.'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
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
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ExamRunnerScreen(
          exam: exam,
          attempt: attempt,
          onOptionSelected: (qId, oId) => repo.saveExamAnswer(attemptId: attempt.id, questionId: qId, selectedOptionId: oId),
          onSubmit: () async {
            await repo.submitExamAttempt(attempt.id);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ));
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exam failed: $e')));
    }
  }

  Future<void> _markNotificationRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      await SupabaseNotificationRepository(wrapper).markRead(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((n) => n.id == notification.id ? n.copyWith(isRead: true) : n).toList();
        if (_unreadCount > 0) _unreadCount--;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notification update failed: $e')));
    }
  }

  Future<void> _markAllNotificationsRead() async {
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      await SupabaseNotificationRepository(wrapper).markAllRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
        _unreadCount = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notification update failed: $e')));
    }
  }

  Future<void> _acknowledgeAnnouncement(Announcement announcement) async {
    if (announcement.isAcknowledged) return;
    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      await SupabaseAnnouncementRepository(wrapper).acknowledgeAnnouncement(announcement.id);
      if (!mounted) return;
      setState(() {
        _announcements = _announcements.map((a) => a.id == announcement.id ? a.copyWith(readAt: DateTime.now(), acknowledgedAt: DateTime.now()) : a).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Acknowledgement failed: $e')));
    }
  }

  // ── build ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
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
        onRetry: _loadAll,
        onOpenWorkspace: nextLesson == null ? null : () => _openWorkspace(nextLesson),
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
        onMarkRead: _markNotificationRead,
        onMarkAllRead: _markAllNotificationsRead,
        onAcknowledge: _acknowledgeAnnouncement,
      ),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: tabs[_selectedIndex],
      ),
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
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.house_outlined),
                selectedIcon: const Icon(Icons.house_rounded, color: AppColors.primary),
                label: context.tr('Home'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book_rounded, color: AppColors.primary),
                label: context.tr('Learn'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.bolt_outlined),
                selectedIcon: const Icon(Icons.bolt_rounded, color: AppColors.primary),
                label: context.tr('Activity'),
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: _unreadCount > 0,
                  label: Text(_unreadCount > 9 ? '9+' : '$_unreadCount'),
                  child: const Icon(Icons.person_outline_rounded),
                ),
                selectedIcon: const Icon(Icons.person_rounded, color: AppColors.primary),
                label: context.tr('Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Session Board screen
// ─────────────────────────────────────────────

class _SessionBoardScreen extends StatelessWidget {
  final PublishedSessionBoard board;

  const _SessionBoardScreen({required this.board});

  @override
  Widget build(BuildContext context) {
    final strokes = decodeSessionBoard(board.boardData);
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
                Chip(avatar: const Icon(Icons.group_work, size: 18), label: Text(board.groupName), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                Chip(avatar: const Icon(Icons.event, size: 18), label: Text(DateFormat.yMMMd().format(board.sessionDate)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                Chip(avatar: const Icon(Icons.update, size: 18), label: Text('${context.tr("Updated")} ${DateFormat.yMMMd().format(board.updatedAt)}'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white, // Force white so dark strokes are visible
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CustomPaint(painter: _BoardPainter(strokes), child: const SizedBox.expand()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final List<BoardStroke> strokes;

  const _BoardPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = const Color(0xFFE5E7EB)..strokeWidth = 1;
    for (var y = 28.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()..color = stroke.color..strokeWidth = stroke.width..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) { path.lineTo(point.dx, point.dy); }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => old.strokes != strokes;
}
