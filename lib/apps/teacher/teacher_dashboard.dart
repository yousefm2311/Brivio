import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client_wrapper.dart';
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
      final teacherId =
          widget.authViewModel.bootstrap?.teacherId ??
          '70000000-0000-0000-0000-000000000001';

      final groups = await teacherRepo.fetchAssignedGroups(teacherId);
      final hwRes = await Supabase.instance.client
          .from('homework')
          .select('id');
      final exRes = await Supabase.instance.client.from('exams').select('id');

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
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(String teacherId) {
    final user = widget.authViewModel.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.purple.shade50,
            child: ListTile(
              leading: const CircleAvatar(
                radius: 28,
                child: Icon(Icons.school, size: 32),
              ),
              title: Text(
                'Welcome, ${user?.fullName ?? "Educator Teacher"}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                'Role: ${(user?.role ?? "teacher").toString().toUpperCase()} | Email: ${user?.email ?? "teacher@academy.com"}',
              ),
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
              child: Text(
                'Error: $_errorMessage',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const Text(
            'Teacher Live Operational Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
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
    final teacherId =
        widget.authViewModel.bootstrap?.teacherId ??
        '70000000-0000-0000-0000-000000000001';

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
              const TeacherCurriculumScreen(),
              const TeacherQuestionBankScreen(),
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

    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.school),
                      label: Text('Teaching'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.book),
                      label: Text('Academic'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.grading),
                      label: Text('Operations'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person),
                      label: Text('Account'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: pages[_selectedIndex]),
              ],
            )
          : pages[_selectedIndex],
      bottomNavigationBar: isWide
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (i) => setState(() => _selectedIndex = i),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.school),
                  label: 'Teaching',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.book),
                  label: 'Academic',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.grading),
                  label: 'Operations',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Account',
                ),
              ],
            ),
    );
  }
}
