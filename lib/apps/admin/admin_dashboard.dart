import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client_wrapper.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/widgets/portal_components.dart';
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
  AcademyCoreSummary? _summary;
  int _parentTotal = 0;

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
      final summaryRepo = SupabaseAcademySummaryRepository(wrapper);

      final results = await Future.wait([
        studentRepo.fetchStudents(),
        parentRepo.fetchParents(),
        teacherRepo.fetchTeachers(),
        branchRepo.fetchBranches(),
        subjectRepo.fetchSubjects(),
        groupRepo.fetchGroups(),
        summaryRepo.fetchSummary(),
      ]);

      if (!mounted) return;
      setState(() {
        _students = (results[0] as PaginatedResult<Student>).data;
        final parentResult = results[1] as PaginatedResult<Parent>;
        _parents = parentResult.data;
        _parentTotal = parentResult.total;
        _teachers = (results[2] as PaginatedResult<Teacher>).data;
        _branches = results[3] as List<Branch>;
        _subjects = results[4] as List<SubjectEntity>;
        _groups = results[5] as List<GroupEntity>;
        _summary = results[6] as AcademyCoreSummary;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _AdminOverview(
        authViewModel: widget.authViewModel,
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        students: _students,
        parents: _parents,
        teachers: _teachers,
        branches: _branches,
        subjects: _subjects,
        groups: _groups,
        summary: _summary,
        parentTotal: _parentTotal,
        onRetry: _loadSummaryData,
        onNavigate: (index) => setState(() => _selectedIndex = index),
      ),
      const BranchManagementScreen(),
      const SubjectManagementScreen(),
      const GroupManagementScreen(),
      const ScheduleManagementScreen(),
      const StudentManagementScreen(),
      const ParentManagementScreen(),
      const TeacherManagementScreen(),
      const StaffManagementScreen(),
      const CurriculumEditorScreen(),
      const QuestionBankScreen(),
      const HomeworkManagementScreen(),
      const ExamManagementScreen(),
      const AttendanceOperationsScreen(),
      const FinanceManagementScreen(),
      const RbacManagementScreen(),
    ];

    return PortalScaffold(
      title: 'Academy Suite',
      subtitle: 'Admin operations',
      icon: Icons.admin_panel_settings,
      accentColor: AppColors.adminRole,
      selectedIndex: _selectedIndex,
      destinations: const [
        PortalDestination(icon: Icons.dashboard, label: 'Overview'),
        PortalDestination(icon: Icons.domain, label: 'Branches'),
        PortalDestination(icon: Icons.book, label: 'Subjects'),
        PortalDestination(icon: Icons.group_work, label: 'Groups'),
        PortalDestination(icon: Icons.schedule, label: 'Schedules'),
        PortalDestination(icon: Icons.school, label: 'Students'),
        PortalDestination(icon: Icons.family_restroom, label: 'Parents'),
        PortalDestination(icon: Icons.person, label: 'Teachers'),
        PortalDestination(icon: Icons.badge, label: 'Staff'),
        PortalDestination(icon: Icons.auto_stories, label: 'Curriculum'),
        PortalDestination(icon: Icons.help_outline, label: 'Questions'),
        PortalDestination(icon: Icons.assignment, label: 'Homework'),
        PortalDestination(icon: Icons.quiz, label: 'Exams'),
        PortalDestination(icon: Icons.event_note, label: 'Attendance'),
        PortalDestination(icon: Icons.monetization_on, label: 'Finance'),
        PortalDestination(icon: Icons.security, label: 'Security'),
      ],
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      onRefresh: _loadSummaryData,
      onSignOut: widget.authViewModel.signOut,
      body: pages[_selectedIndex],
    );
  }
}

class _AdminOverview extends StatelessWidget {
  final AuthViewModel authViewModel;
  final bool isLoading;
  final String? errorMessage;
  final List<Student> students;
  final List<Parent> parents;
  final List<Teacher> teachers;
  final List<Branch> branches;
  final List<SubjectEntity> subjects;
  final List<GroupEntity> groups;
  final AcademyCoreSummary? summary;
  final int parentTotal;
  final VoidCallback onRetry;
  final ValueChanged<int> onNavigate;

  const _AdminOverview({
    required this.authViewModel,
    required this.isLoading,
    required this.errorMessage,
    required this.students,
    required this.parents,
    required this.teachers,
    required this.branches,
    required this.subjects,
    required this.groups,
    required this.summary,
    required this.parentTotal,
    required this.onRetry,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final user = authViewModel.currentUser;
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PortalHeader(
            eyebrow: 'Admin Portal',
            title: 'Welcome, ${user?.fullName ?? "Administrator"}',
            subtitle:
                '${authViewModel.userRole?.displayName ?? "Admin"} - ${user?.branchId ?? "Global access"}',
            icon: Icons.admin_panel_settings,
            accentColor: AppColors.adminRole,
            trailing: IconButton.filledTonal(
              tooltip: 'Refresh',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            PortalErrorBanner(message: errorMessage!, onRetry: onRetry),
          ],
          const SizedBox(height: 18),
          const PortalSectionTitle(
            title: 'Academy Operations',
            subtitle: 'Live counts from the production database.',
          ),
          const SizedBox(height: 12),
          PortalMetricGrid(
            children: [
              PortalMetricCard(
                label: 'Branches',
                value: (summary?.activeBranches ?? branches.length).toString(),
                icon: Icons.domain,
                accentColor: Colors.indigo,
                onTap: () => onNavigate(1),
              ),
              PortalMetricCard(
                label: 'Subjects',
                value: (summary?.activeSubjects ?? subjects.length).toString(),
                icon: Icons.book,
                accentColor: Colors.deepOrange,
                onTap: () => onNavigate(2),
              ),
              PortalMetricCard(
                label: 'Groups',
                value: (summary?.activeGroups ?? groups.length).toString(),
                icon: Icons.group_work,
                accentColor: Colors.blue,
                onTap: () => onNavigate(3),
              ),
              PortalMetricCard(
                label: 'Students',
                value: (summary?.activeStudents ?? students.length).toString(),
                icon: Icons.school,
                accentColor: Colors.green,
                onTap: () => onNavigate(5),
              ),
              PortalMetricCard(
                label: 'Parents',
                value: (parentTotal == 0 ? parents.length : parentTotal)
                    .toString(),
                icon: Icons.family_restroom,
                accentColor: Colors.orange,
                onTap: () => onNavigate(6),
              ),
              PortalMetricCard(
                label: 'Teachers',
                value: (summary?.activeTeachers ?? teachers.length).toString(),
                icon: Icons.person,
                accentColor: Colors.purple,
                onTap: () => onNavigate(7),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
