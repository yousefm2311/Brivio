import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/report_generator_service.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../viewmodels/reports_dashboard_viewmodel.dart';
import 'groups_schedules_report_screen.dart';

class ReportsDashboardScreen extends StatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  final ReportGeneratorService _reportService = getIt<ReportGeneratorService>();
  final ReportsDashboardViewModel _viewModel = ReportsDashboardViewModel();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _viewModel.loadData();
  }

  Future<void> _generateReport(
    String title,
    Future<void> Function() generateAction,
  ) async {
    setState(() => _isGenerating = true);
    try {
      await generateAction();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$title generated successfully!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate $title: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Reports Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.cosmicGradient),
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Available Reports',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generate and download premium reports for your institution.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PortalMetricGrid(
                    children: [
                      PortalMetricCard(
                        label: 'Student Grades',
                        value: 'Generate',
                        icon: Icons.school,
                        accentColor: Colors.blue,
                        onTap: () => _generateReport(
                          'Student Grades Report',
                          () => _reportService.generateGradesReport(
                            className: 'All Students',
                            studentsData: _viewModel.studentsData,
                          ),
                        ),
                      ),
                      PortalMetricCard(
                        label: 'Attendance',
                        value: 'Generate',
                        icon: Icons.event_note,
                        accentColor: Colors.green,
                        onTap: () => _generateReport(
                          'Attendance Report',
                          () => _reportService.generateAttendanceReport(
                            className: 'All Students',
                            attendanceData: _viewModel.attendanceData,
                          ),
                        ),
                      ),
                      PortalMetricCard(
                        label: 'Financial',
                        value: 'Generate',
                        icon: Icons.monetization_on,
                        accentColor: Colors.orange,
                        onTap: () => _generateReport(
                          'Financial Report',
                          () => _reportService.generateFinancialReport(
                            financialData: _viewModel.financialData,
                          ),
                        ),
                      ),
                      PortalMetricCard(
                        label: 'Teachers',
                        value: 'Generate',
                        icon: Icons.person,
                        accentColor: Colors.purple,
                        onTap: () => _generateReport(
                          'Teacher Metrics Report',
                          () => _reportService.generateTeacherMetricsReport(
                            teacherData: _viewModel.teacherData,
                          ),
                        ),
                      ),
                      PortalMetricCard(
                        label: 'Groups & Schedules',
                        value: 'View',
                        icon: Icons.schedule,
                        accentColor: Colors.red,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const GroupsSchedulesReportScreen(),
                            ),
                          );
                        },
                      ),
                      PortalMetricCard(
                        label: 'Parents',
                        value: 'Generate',
                        icon: Icons.family_restroom,
                        accentColor: Colors.deepPurple,
                        onTap: () => _generateReport(
                          'Linked Parents Report',
                          () => _reportService.generateParentsReport(
                            parentsData: _viewModel.parentsData,
                          ),
                        ),
                      ),
                      PortalMetricCard(
                        label: 'Homework',
                        value: 'Generate',
                        icon: Icons.menu_book,
                        accentColor: Colors.brown,
                        onTap: () => _generateReport(
                          'Homework Completion Report',
                          () => _reportService.generateHomeworkReport(
                            homeworkData: _viewModel.homeworkData,
                          ),
                        ),
                      ),
                      PortalMetricCard(
                        label: 'Curriculum',
                        value: 'Generate',
                        icon: Icons.library_books,
                        accentColor: Colors.blueGrey,
                        onTap: () => _generateReport(
                          'Curriculum Progress Report',
                          () => _reportService.generateCurriculumReport(
                            curriculumData: _viewModel.curriculumData,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_isGenerating)
                Container(
                  color: Colors.black45,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
