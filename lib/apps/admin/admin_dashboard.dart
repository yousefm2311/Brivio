import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client_wrapper.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/academy/presentation/screens/branch_management_screen.dart';
import '../../features/academy/presentation/screens/group_management_screen.dart';
import '../../features/academy/presentation/screens/schedule_management_screen.dart';
import '../../features/academy/presentation/screens/subject_management_screen.dart';
import '../../features/assessment/presentation/screens/exam_management_screen.dart';
import '../../features/assessment/presentation/screens/homework_management_screen.dart';
import '../../features/assessment/presentation/screens/question_bank_screen.dart';
import '../../features/attendance/presentation/screens/attendance_operations_screen.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/curriculum/presentation/screens/curriculum_editor_screen.dart';
import '../../features/payments/presentation/screens/finance_management_screen.dart';
import '../../features/people/presentation/screens/parent_management_screen.dart';
import '../../features/people/presentation/screens/staff_management_screen.dart';
import '../../features/people/presentation/screens/student_management_screen.dart';
import '../../features/people/presentation/screens/teacher_management_screen.dart';
import '../../features/security/presentation/screens/rbac_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  final AuthViewModel authViewModel;

  const AdminDashboard({super.key, required this.authViewModel});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<Student> _students = [];
  List<Parent> _parents = [];
  List<Teacher> _teachers = [];
  List<Branch> _branches = [];
  List<SubjectEntity> _subjects = [];
  List<GroupEntity> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadSummaryData();
  }

  Future<void> _loadSummaryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final studentRepo = SupabaseStudentRepository(wrapper);
      final parentRepo = SupabaseParentRepository(wrapper);
      final teacherRepo = SupabaseTeacherRepository(wrapper);
      final branchRepo = SupabaseBranchRepository(wrapper);
      final subjectRepo = SupabaseSubjectRepository(wrapper);
      final groupRepo = SupabaseGroupRepository(wrapper);

      final studentRes = await studentRepo.fetchStudents();
      final parentRes = await parentRepo.fetchParents();
      final teacherRes = await teacherRepo.fetchTeachers();
      final branchesRes = await branchRepo.fetchBranches();
      final subjectsRes = await subjectRepo.fetchSubjects();
      final groupsRes = await groupRepo.fetchGroups();

      setState(() {
        _students = studentRes.data;
        _parents = parentRes.data;
        _teachers = teacherRes.data;
        _branches = branchesRes;
        _subjects = subjectsRes;
        _groups = groupsRes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authViewModel.currentUser;

    final List<Widget> tabs = [
      // 0: Overview Dashboard Summary
      SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.admin_panel_settings, color: Colors.white),
                ),
                title: Text(
                  'Welcome, ${user?.fullName ?? "Administrator"}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Role: ${widget.authViewModel.userRole?.displayName ?? "Admin"} | Branch: ${user?.branchId ?? "Global"}',
                ),
                trailing: ElevatedButton.icon(
                  onPressed: () => widget.authViewModel.signOut(),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Error loading summary: $_errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Academy Operations Live Dashboard',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildSummaryCard(
                  'Branches',
                  _branches.length.toString(),
                  Icons.domain,
                  Colors.indigo,
                  () => setState(() => _selectedIndex = 1),
                ),
                _buildSummaryCard(
                  'Subjects',
                  _subjects.length.toString(),
                  Icons.book,
                  Colors.deepOrange,
                  () => setState(() => _selectedIndex = 2),
                ),
                _buildSummaryCard(
                  'Groups',
                  _groups.length.toString(),
                  Icons.group_work,
                  Colors.blue,
                  () => setState(() => _selectedIndex = 3),
                ),
                _buildSummaryCard(
                  'Students',
                  _students.length.toString(),
                  Icons.school,
                  Colors.green,
                  () => setState(() => _selectedIndex = 5),
                ),
                _buildSummaryCard(
                  'Parents',
                  _parents.length.toString(),
                  Icons.family_restroom,
                  Colors.orange,
                  () => setState(() => _selectedIndex = 6),
                ),
                _buildSummaryCard(
                  'Teachers',
                  _teachers.length.toString(),
                  Icons.person,
                  Colors.purple,
                  () => setState(() => _selectedIndex = 7),
                ),
              ],
            ),
          ],
        ),
      ),
      // 1: Branches
      const BranchManagementScreen(),
      // 2: Subjects
      const SubjectManagementScreen(),
      // 3: Groups
      const GroupManagementScreen(),
      // 4: Schedules
      const ScheduleManagementScreen(),
      // 5: Students
      const StudentManagementScreen(),
      // 6: Parents
      const ParentManagementScreen(),
      // 7: Teachers
      const TeacherManagementScreen(),
      // 8: Staff
      const StaffManagementScreen(),
      // 9: Curriculum
      const CurriculumEditorScreen(),
      // 10: Question Bank
      const QuestionBankScreen(),
      // 11: Homework
      const HomeworkManagementScreen(),
      // 12: Exams
      const ExamManagementScreen(),
      // 13: Attendance
      const AttendanceOperationsScreen(),
      // 14: Finance
      const FinanceManagementScreen(),
      // 15: Security RBAC
      const RbacManagementScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academy Management Suite — Admin Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSummaryData,
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.domain),
                label: Text('Branches'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.book),
                label: Text('Subjects'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.group_work),
                label: Text('Groups'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.schedule),
                label: Text('Schedules'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.school),
                label: Text('Students'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.family_restroom),
                label: Text('Parents'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person),
                label: Text('Teachers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.badge),
                label: Text('Staff'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.auto_stories),
                label: Text('Curriculum'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.help_outline),
                label: Text('Questions'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment),
                label: Text('Homework'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.quiz),
                label: Text('Exams'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.event_note),
                label: Text('Attendance'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.monetization_on),
                label: Text('Finance'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.security),
                label: Text('Security'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: tabs[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String count,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
