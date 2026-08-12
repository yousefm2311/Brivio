import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../viewmodels/attendance_reports_viewmodel.dart';

class AttendanceReportsScreen extends StatefulWidget {
  const AttendanceReportsScreen({super.key});

  @override
  State<AttendanceReportsScreen> createState() => _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState extends State<AttendanceReportsScreen> with SingleTickerProviderStateMixin {
  final ReportGeneratorService _reportService = getIt<ReportGeneratorService>();
  final AttendanceReportsViewModel _viewModel = AttendanceReportsViewModel();
  late TabController _tabController;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _viewModel.loadData();
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generatePdf(String groupName, List<Map<String, dynamic>> data, String personType) async {
    setState(() => _isGenerating = true);
    try {
      await _reportService.generateAttendanceReport(
        className: groupName,
        attendanceData: data,
        personType: personType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$groupName Attendance Report generated successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate report: $e'), backgroundColor: AppColors.error),
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
        title: const Text('Attendance & Departure Reports', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.secondary,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Teachers'),
            Tab(text: 'Staff'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.cosmicGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              if (_viewModel.isLoading)
                const Center(child: CircularProgressIndicator(color: AppColors.secondary))
              else
                TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReportTab('Students', _viewModel.studentAttendance, 'Student'),
                    _buildReportTab('Teachers', _viewModel.teacherAttendance, 'Teacher'),
                    _buildReportTab('Staff', _viewModel.staffAttendance, 'Staff Member'),
                  ],
                ),
              if (_isGenerating)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.secondary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportTab(String groupName, List<Map<String, dynamic>> data, String personType) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$groupName Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            ElevatedButton.icon(
              onPressed: () => _generatePdf(groupName, data, personType),
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text('Export PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              columns: [
                DataColumn(label: Text('$personType Name', style: const TextStyle(color: Colors.white))),
                const DataColumn(label: Text('Total Present', style: TextStyle(color: Colors.white))),
                const DataColumn(label: Text('Total Absent', style: TextStyle(color: Colors.white))),
                const DataColumn(label: Text('Status', style: TextStyle(color: Colors.white))),
              ],
              rows: data.map((record) {
                return DataRow(cells: [
                  DataCell(Text(record['name'] ?? '', style: const TextStyle(color: Colors.white70))),
                  DataCell(Text(record['present']?.toString() ?? '0', style: const TextStyle(color: Colors.white70))),
                  DataCell(Text(record['absent']?.toString() ?? '0', style: const TextStyle(color: Colors.white70))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(record['status'] ?? '').withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getStatusColor(record['status'] ?? '').withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        record['status'] ?? '',
                        style: TextStyle(
                          color: _getStatusColor(record['status'] ?? ''),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'perfect':
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.blue;
      case 'warning':
        return Colors.orange;
      case 'poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
