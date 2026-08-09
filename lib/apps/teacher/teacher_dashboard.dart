import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client_wrapper.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/widgets/portal_components.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/academy/presentation/screens/teacher_groups_screen.dart';
import '../../features/academy/presentation/screens/teacher_schedule_screen.dart';
import '../../features/academy/presentation/screens/teacher_today_screen.dart';
import '../../features/assessment/presentation/screens/teacher_exam_screen.dart';
import '../../features/assessment/presentation/screens/teacher_grading_screen.dart';
import '../../features/assessment/presentation/screens/teacher_homework_screen.dart';
import '../../features/assessment/presentation/screens/teacher_question_bank_screen.dart';
import '../../features/attendance/presentation/screens/teacher_attendance_screen.dart';
import '../../features/curriculum/presentation/screens/teacher_curriculum_screen.dart';
import '../../features/people/presentation/screens/teacher_profile_screen.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/payments/presentation/screens/teacher_finance_screen.dart';
import '../../features/study_workspace/presentation/screens/study_replay_screen.dart';

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
  List<_TeacherGroupAnalytics> _groupAnalytics = [];

  @override
  void initState() {
    super.initState();
    _loadTeacherMetrics();
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
              .map(_TeacherGroupAnalytics.fromJson)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
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

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return PortalMetricCard(
      label: title,
      value: value,
      icon: icon,
      accentColor: color,
      onTap: onTap,
    );
  }

  Widget _buildOverviewTab(String teacherId) {
    final user = widget.authViewModel.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalHeader(
            eyebrow: 'Teacher Portal',
            title: 'Welcome, ${user?.fullName ?? "Educator Teacher"}',
            subtitle:
                '${(user?.role ?? "teacher").toString().toUpperCase()} - ${user?.email ?? "No email"}',
            icon: Icons.school,
            accentColor: AppColors.teacherRole,
            trailing: IconButton.filledTonal(
              tooltip: 'Refresh',
              onPressed: _loadTeacherMetrics,
              icon: const Icon(Icons.refresh),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: PortalErrorBanner(
                message: _errorMessage!,
                onRetry: _loadTeacherMetrics,
              ),
            ),
          const PortalSectionTitle(
            title: 'Teaching Operations',
            subtitle: 'Groups, assignments, exams, attendance, and grading.',
          ),
          const SizedBox(height: 12),
          PortalMetricGrid(
            children: [
              _buildSummaryCard(
                'Assigned Groups',
                '${_assignedGroups.length}',
                Icons.group,
                Colors.indigo,
                () => setState(() => _selectedIndex = 1),
              ),
              _buildSummaryCard(
                'Today\'s Schedule',
                '$_todaySessionsCount',
                Icons.alarm,
                Colors.orange,
                () => setState(() => _selectedIndex = 1),
              ),
              _buildSummaryCard(
                'Published Homework',
                '$_openHomeworkCount',
                Icons.assignment,
                Colors.teal,
                () => setState(() => _selectedIndex = 2),
              ),
              _buildSummaryCard(
                'Published Exams',
                '$_publishedExamsCount',
                Icons.quiz,
                Colors.purple,
                () => setState(() => _selectedIndex = 2),
              ),
              _buildSummaryCard(
                'Daily Attendance',
                'Roll Call',
                Icons.event_note,
                Colors.green,
                () => setState(() => _selectedIndex = 3),
              ),
              _buildSummaryCard(
                'Manual Grading Queue',
                '$_gradingQueueCount',
                Icons.grading,
                Colors.amber.shade800,
                () => setState(() => _selectedIndex = 3),
              ),
              _buildSummaryCard(
                'Saved Boards',
                '$_savedBoardCount',
                Icons.draw,
                Colors.blueGrey,
                () => setState(() => _selectedIndex = 3),
              ),
              _buildSummaryCard(
                'Group Finance',
                'Cash',
                Icons.payments,
                Colors.green.shade700,
                () => setState(() => _selectedIndex = 4),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const PortalSectionTitle(
            title: 'Group Performance',
            subtitle:
                'Attendance, submissions, and exam scores from your assigned groups.',
          ),
          const SizedBox(height: 12),
          if (_groupAnalytics.isEmpty)
            const _TeacherEmptyAnalyticsCard()
          else
            ..._groupAnalytics.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TeacherGroupAnalyticsCard(item: item),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacherId = widget.authViewModel.bootstrap?.teacherId;

    if (teacherId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Teacher Portal'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => widget.authViewModel.signOut(),
            ),
          ],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This account is not linked to a teacher profile yet. Ask an admin to provision the teacher record before using the teacher portal.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final List<Widget> pages = [
      _buildOverviewTab(teacherId),
      // Tab 1: My Teaching (Subtabs)
      DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('My Teaching Workspaces'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.alarm), text: 'Today'),
                Tab(icon: Icon(Icons.group), text: 'My Groups'),
                Tab(icon: Icon(Icons.schedule), text: 'Schedule'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              TeacherTodayScreen(teacherId: teacherId),
              TeacherGroupsScreen(teacherId: teacherId),
              TeacherScheduleScreen(teacherId: teacherId),
            ],
          ),
        ),
      ),
      // Tab 2: Academic (Subtabs)
      DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Academic & Content Workspace'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(icon: Icon(Icons.school), text: 'Curriculum'),
                Tab(icon: Icon(Icons.help_outline), text: 'Question Bank'),
                Tab(icon: Icon(Icons.assignment), text: 'Homework'),
                Tab(icon: Icon(Icons.quiz), text: 'Exams'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              TeacherCurriculumScreen(teacherId: teacherId),
              TeacherQuestionBankScreen(teacherId: teacherId),
              TeacherHomeworkScreen(teacherId: teacherId),
              TeacherExamScreen(teacherId: teacherId),
            ],
          ),
        ),
      ),
      // Tab 3: Operations & Grading (Subtabs)
      DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Operations & Grading Workspace'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.event_note), text: 'Attendance Roll Call'),
                Tab(icon: Icon(Icons.grading), text: 'Grading Queue'),
                Tab(icon: Icon(Icons.video_library), text: 'Study Replay'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              TeacherAttendanceScreen(teacherId: teacherId),
              TeacherGradingScreen(teacherId: teacherId),
              StudyReplayScreen(teacherId: teacherId),
            ],
          ),
        ),
      ),
      // Tab 4: Finance
      TeacherFinanceScreen(teacherId: teacherId),
      // Tab 4: Profile Account
      TeacherProfileScreen(authViewModel: widget.authViewModel),
    ];

    return PortalScaffold(
      title: 'Teacher Studio',
      subtitle: 'Teaching workspace',
      icon: Icons.school,
      accentColor: AppColors.teacherRole,
      selectedIndex: _selectedIndex,
      destinations: const [
        PortalDestination(icon: Icons.dashboard, label: 'Home'),
        PortalDestination(icon: Icons.school, label: 'Teaching'),
        PortalDestination(icon: Icons.book, label: 'Academic'),
        PortalDestination(icon: Icons.grading, label: 'Operations'),
        PortalDestination(icon: Icons.payments, label: 'Finance'),
        PortalDestination(icon: Icons.person, label: 'Account'),
      ],
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      onRefresh: _loadTeacherMetrics,
      onSignOut: widget.authViewModel.signOut,
      body: pages[_selectedIndex],
    );
  }
}

class _TeacherGroupAnalytics {
  final String groupName;
  final String groupCode;
  final int studentCount;
  final int completedSessions;
  final double attendanceRate;
  final int absentCount;
  final int pendingHomeworkCount;
  final double averageExamScore;

  const _TeacherGroupAnalytics({
    required this.groupName,
    required this.groupCode,
    required this.studentCount,
    required this.completedSessions,
    required this.attendanceRate,
    required this.absentCount,
    required this.pendingHomeworkCount,
    required this.averageExamScore,
  });

  factory _TeacherGroupAnalytics.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _TeacherGroupAnalytics(
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

class _TeacherGroupAnalyticsCard extends StatelessWidget {
  final _TeacherGroupAnalytics item;

  const _TeacherGroupAnalyticsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.teacherRole,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.insights),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.groupName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        [
                          if (item.groupCode.isNotEmpty) item.groupCode,
                          '${item.studentCount} students',
                          '${item.completedSessions} completed sessions',
                        ].join(' | '),
                      ),
                    ],
                  ),
                ),
                PortalStatusChip(
                  status: item.attendanceRate >= 85
                      ? 'healthy'
                      : item.attendanceRate >= 65
                      ? 'watch'
                      : 'risk',
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final children = [
                  _AnalyticsMiniMetric(
                    icon: Icons.event_available,
                    label: 'Attendance',
                    value: '${item.attendanceRate.toStringAsFixed(1)}%',
                    color: AppColors.success,
                  ),
                  _AnalyticsMiniMetric(
                    icon: Icons.cancel,
                    label: 'Absences',
                    value: item.absentCount.toString(),
                    color: AppColors.error,
                  ),
                  _AnalyticsMiniMetric(
                    icon: Icons.assignment_late,
                    label: 'Pending HW',
                    value: item.pendingHomeworkCount.toString(),
                    color: AppColors.warning,
                  ),
                  _AnalyticsMiniMetric(
                    icon: Icons.quiz,
                    label: 'Exam Avg',
                    value: '${item.averageExamScore.toStringAsFixed(1)}%',
                    color: AppColors.info,
                  ),
                ];
                if (isWide) {
                  return Row(
                    children: children
                        .map(
                          (child) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: child,
                            ),
                          ),
                        )
                        .toList(),
                  );
                }
                return Wrap(spacing: 8, runSpacing: 8, children: children);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsMiniMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AnalyticsMiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 148),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherEmptyAnalyticsCard extends StatelessWidget {
  const _TeacherEmptyAnalyticsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.insights_outlined, color: AppColors.info),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Analytics will appear after migrations are applied and groups start producing attendance, homework, and exam data.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
