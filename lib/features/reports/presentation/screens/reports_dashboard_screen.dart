import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';

class ReportsDashboardScreen extends StatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  final ReportGeneratorService _reportService = getIt<ReportGeneratorService>();
  bool _isGenerating = false;

  Future<void> _generateReport(String title, Future<void> Function() generateAction) async {
    setState(() => _isGenerating = true);
    try {
      await generateAction();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title generated successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate $title: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Dashboard'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const PortalSectionTitle(
                title: 'Available Reports',
                subtitle: 'Generate and download premium reports for your institution.',
              ),
              const SizedBox(height: 24),
              PortalMetricGrid(
                children: [
                  PortalMetricCard(
                    label: 'Student Grades',
                    value: 'Generate',
                    icon: Icons.school,
                    accentColor: Colors.blue,
                    onTap: () => _generateReport('Student Grades Report', () => _reportService.generateGradesReport(
                      className: 'All Students',
                      studentsData: [
                        {'name': 'Alice', 'exam_score': 95, 'homework_score': 100, 'missing_assignments': 0},
                        {'name': 'Bob', 'exam_score': 78, 'homework_score': 85, 'missing_assignments': 1},
                      ],
                    )),
                  ),
                  PortalMetricCard(
                    label: 'Attendance',
                    value: 'Generate',
                    icon: Icons.event_note,
                    accentColor: Colors.green,
                    onTap: () => _generateReport('Attendance Report', () => _reportService.generateAttendanceReport(
                      className: 'All Students',
                      attendanceData: [
                        {'name': 'Alice', 'present': 20, 'absent': 0, 'absence_dates': ''},
                        {'name': 'Bob', 'present': 18, 'absent': 2, 'absence_dates': '2026-08-01, 2026-08-05'},
                      ],
                    )),
                  ),
                  PortalMetricCard(
                    label: 'Financial',
                    value: 'Generate',
                    icon: Icons.monetization_on,
                    accentColor: Colors.orange,
                    onTap: () => _generateReport('Financial Report', () => _reportService.generateFinancialReport(
                      financialData: [
                        {'date': '2026-08-10', 'description': 'Tuition Fee - Alice', 'type': 'Inflow', 'amount': 500, 'notes': ''},
                        {'date': '2026-08-11', 'description': 'Office Supplies', 'type': 'Outflow', 'amount': -50, 'notes': 'Stationery'},
                      ],
                    )),
                  ),
                  PortalMetricCard(
                    label: 'Teachers',
                    value: 'Generate',
                    icon: Icons.person,
                    accentColor: Colors.purple,
                    onTap: () => _generateReport('Teacher Metrics Report', () => _reportService.generateTeacherMetricsReport(
                      teacherData: [
                        {'name': 'Mr. Smith', 'classes_taught': 5, 'avg_attendance': 95.5},
                        {'name': 'Mrs. Doe', 'classes_taught': 3, 'avg_attendance': 98.0},
                      ],
                    )),
                  ),
                ],
              ),
            ],
          ),
          if (_isGenerating)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
