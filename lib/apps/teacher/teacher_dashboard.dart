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

      if (mounted) {
        setState(() {
          _assignedGroups = groups;
          _openHomeworkCount = (hwRes as List).length;
          _publishedExamsCount = (exRes as List).length;
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
                'Active',
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
                'Open Queue',
                Icons.grading,
                Colors.amber.shade800,
                () => setState(() => _selectedIndex = 3),
              ),
            ],
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
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Operations & Grading Workspace'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.event_note), text: 'Attendance Roll Call'),
                Tab(icon: Icon(Icons.grading), text: 'Grading Queue'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              TeacherAttendanceScreen(teacherId: teacherId),
              TeacherGradingScreen(teacherId: teacherId),
            ],
          ),
        ),
      ),
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
        PortalDestination(icon: Icons.person, label: 'Account'),
      ],
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      onRefresh: _loadTeacherMetrics,
      onSignOut: widget.authViewModel.signOut,
      body: pages[_selectedIndex],
    );
  }
}
