import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/di/injection.dart';
import '../../core/error/supabase_error_handler.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/supabase_client_wrapper.dart';
import '../../design_system/tokens/colors.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/communication/domain/models/notification.dart';
import '../../features/communication/domain/repositories/i_notification_repository.dart';
import '../../features/communication/presentation/screens/notification_center_screen.dart';
import '../../features/communication/presentation/viewmodels/notification_center_viewmodel.dart';
import 'tabs/home_tab.dart';
import 'tabs/classes_tab.dart';
import 'tabs/workspace_tab.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/account_tab.dart';

class TeacherDashboard extends StatefulWidget {
  final AuthViewModel authViewModel;

  const TeacherDashboard({super.key, required this.authViewModel});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<GroupEntity> _assignedGroups = [];
  int _openHomeworkCount = 0;
  int _publishedExamsCount = 0;
  int _gradingQueueCount = 0;
  int _todaySessionsCount = 0;
  int _savedBoardCount = 0;
  List<TeacherGroupAnalytics> _groupAnalytics = [];
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription<AppNotification>? _notificationSubscription;
  late final NotificationCenterViewModel _notificationCenterViewModel;

  int get unreadCount => _unreadCount;
  List<AppNotification> get notifications => _notifications;

  @override
  void initState() {
    super.initState();
    _notificationCenterViewModel = NotificationCenterViewModel(
      getIt<INotificationRepository>(),
    );
    _notificationCenterViewModel.addListener(_syncNotificationCenterState);
    _subscribeToNotifications();
    _loadTeacherMetrics();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _notifications = _notificationCenterViewModel.notifications;
        _unreadCount = _notificationCenterViewModel.unreadCount;
      });
    });
  }

  void _subscribeToNotifications() {
    final notificationRepo = getIt<INotificationRepository>();
    _notificationSubscription = notificationRepo
        .subscribeToNotifications()
        .listen(
          (notification) {
            if (!mounted) return;
            setState(() {
              _notifications.insert(0, notification);
              _unreadCount++;
            });
          },
          onError: (error) {
            debugPrint('Notification stream error caught: $error');
          },
        );
  }

  Future<void> _loadTeacherMetrics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final teacherRepo = SupabaseTeacherRepository(wrapper);
      final teacherId = widget.authViewModel.bootstrap?.teacherId;
      final profileId = widget.authViewModel.currentUser?.id;

      if (teacherId == null || profileId == null) {
        throw Exception(
          'Teacher account is missing its linked teacher profile. Contact an admin to complete provisioning.',
        );
      }

      final notificationRepo = getIt<INotificationRepository>();
      final initialNotifications = await notificationRepo
          .getNotifications()
          .catchError((_) => <AppNotification>[]);
      final initialUnreadCount = await notificationRepo
          .getUnreadCount()
          .catchError((_) => 0);

      final groups = await teacherRepo.fetchAssignedGroups(teacherId);
      final hwRes = await Supabase.instance.client
          .from('homework')
          .select('id')
          .eq('assigned_by', profileId);
      final exRes = await Supabase.instance.client
          .from('exams')
          .select('id')
          .eq('created_by', profileId);
      final gradingQueue = await _safeList(
        () => Supabase.instance.client.rpc(
          'get_teacher_grading_queue',
          params: {'p_teacher_id': teacherId},
        ),
      );
      final groupIds = groups.map((group) => group.id).toList();
      final today = DateTime.now().toIso8601String().split('T').first;
      final todaySessions = groupIds.isEmpty
          ? <dynamic>[]
          : await _safeList(
              () => Supabase.instance.client
                  .from('class_sessions')
                  .select('id')
                  .inFilter('group_id', groupIds)
                  .eq('session_date', today),
            );
      final savedBoards = await _safeList(
        () => Supabase.instance.client
            .from('class_session_boards')
            .select('id')
            .eq('teacher_id', teacherId),
      );
      final analytics = await _safeList(
        () =>
            Supabase.instance.client.rpc('get_current_teacher_group_analytics'),
      );

      if (mounted) {
        setState(() {
          _assignedGroups = groups;
          _openHomeworkCount = (hwRes as List).length;
          _publishedExamsCount = (exRes as List).length;
          _gradingQueueCount = gradingQueue.length;
          _todaySessionsCount = todaySessions.length;
          _savedBoardCount = savedBoards.length;
          _groupAnalytics = analytics
              .whereType<Map>()
              .map(TeacherGroupAnalytics.fromJson)
              .toList();
          _notifications = initialNotifications;
          _unreadCount = initialUnreadCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = SupabaseErrorHandler.parseError(e);
          _isLoading = false;
        });
      }
    }
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
    final teacherId = widget.authViewModel.bootstrap?.teacherId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    if (teacherId == null) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(context.tr('Teacher Portal')),
          actions: [
            IconButton(
              tooltip: context.tr('Sign out'),
              icon: const Icon(Icons.logout),
              onPressed: () => widget.authViewModel.signOut(),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.tr(
                'This account is not linked to a teacher profile yet. Ask an admin to provision the teacher record before using the teacher portal.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final tabs = [
      HomeTab(
        user: widget.authViewModel.currentUser,
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        assignedGroupsCount: _assignedGroups.length,
        openHomeworkCount: _openHomeworkCount,
        publishedExamsCount: _publishedExamsCount,
        gradingQueueCount: _gradingQueueCount,
        todaySessionsCount: _todaySessionsCount,
        savedBoardCount: _savedBoardCount,
        groupAnalytics: _groupAnalytics,
        onRetry: _loadTeacherMetrics,
        onNavigate: (i) => setState(() => _selectedIndex = i),
      ),
      ClassesTab(teacherId: teacherId),
      WorkspaceTab(teacherId: teacherId),
      AnalyticsTab(profileId: widget.authViewModel.currentUser!.id),
      NotificationCenterScreen(viewModel: _notificationCenterViewModel),
      AccountTab(teacherId: teacherId, authViewModel: widget.authViewModel),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        final body = SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: tabs[_selectedIndex],
          ),
        );

        if (isWide) {
          return Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: bgColor,
            body: Row(
              children: [
                NavigationRail(
                  backgroundColor: surfaceColor,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                  labelType: NavigationRailLabelType.all,
                  indicatorColor: AppColors.teacherRole.withValues(alpha: 0.12),
                  selectedIconTheme: const IconThemeData(
                    color: AppColors.teacherRole,
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.dashboard_outlined),
                      selectedIcon: const Icon(Icons.dashboard_rounded),
                      label: Text(context.tr('Home')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.school_outlined),
                      selectedIcon: const Icon(Icons.school_rounded),
                      label: Text(context.tr('Classes')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.grading_outlined),
                      selectedIcon: const Icon(Icons.grading_rounded),
                      label: Text(context.tr('Workspace')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.analytics_outlined),
                      selectedIcon: const Icon(Icons.analytics_rounded),
                      label: Text(context.tr('Analytics')),
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
          resizeToAvoidBottomInset: false,
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
                indicatorColor: AppColors.teacherRole.withValues(alpha: 0.12),
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) =>
                    setState(() => _selectedIndex = i),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: const Icon(
                      Icons.dashboard_rounded,
                      color: AppColors.teacherRole,
                    ),
                    label: context.tr('Home'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.school_outlined),
                    selectedIcon: const Icon(
                      Icons.school_rounded,
                      color: AppColors.teacherRole,
                    ),
                    label: context.tr('Classes'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.grading_outlined),
                    selectedIcon: const Icon(
                      Icons.grading_rounded,
                      color: AppColors.teacherRole,
                    ),
                    label: context.tr('Workspace'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.analytics_outlined),
                    selectedIcon: const Icon(
                      Icons.analytics_rounded,
                      color: AppColors.teacherRole,
                    ),
                    label: context.tr('Analytics'),
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: _unreadCount > 0,
                      label: Text(_unreadCount > 9 ? '9+' : '$_unreadCount'),
                      child: const Icon(Icons.notifications_none_rounded),
                    ),
                    selectedIcon: const Icon(
                      Icons.notifications_rounded,
                      color: AppColors.teacherRole,
                    ),
                    label: context.tr('Notifications'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline_rounded),
                    selectedIcon: const Icon(
                      Icons.person_rounded,
                      color: AppColors.teacherRole,
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

class TeacherGroupAnalytics {
  final String groupName;
  final String groupCode;
  final int studentCount;
  final int completedSessions;
  final double attendanceRate;
  final int absentCount;
  final int pendingHomeworkCount;
  final double averageExamScore;

  const TeacherGroupAnalytics({
    required this.groupName,
    required this.groupCode,
    required this.studentCount,
    required this.completedSessions,
    required this.attendanceRate,
    required this.absentCount,
    required this.pendingHomeworkCount,
    required this.averageExamScore,
  });

  factory TeacherGroupAnalytics.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return TeacherGroupAnalytics(
      groupName: json['group_name']?.toString() ?? 'Group',
      groupCode: json['group_code']?.toString() ?? '',
      studentCount: (json['student_count'] as num?)?.round() ?? 0,
      completedSessions: (json['completed_sessions'] as num?)?.round() ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0,
      absentCount: (json['absent_count'] as num?)?.round() ?? 0,
      pendingHomeworkCount:
          (json['pending_homework_count'] as num?)?.round() ?? 0,
      averageExamScore: (json['average_exam_score'] as num?)?.toDouble() ?? 0,
    );
  }
}
