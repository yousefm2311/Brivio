import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../viewmodels/groups_schedules_viewmodel.dart';

class GroupsSchedulesReportScreen extends StatefulWidget {
  const GroupsSchedulesReportScreen({super.key});

  @override
  State<GroupsSchedulesReportScreen> createState() => _GroupsSchedulesReportScreenState();
}

class _GroupsSchedulesReportScreenState extends State<GroupsSchedulesReportScreen> {
  final ReportGeneratorService _reportService = getIt<ReportGeneratorService>();
  final GroupsSchedulesViewModel _viewModel = GroupsSchedulesViewModel();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChange);
    _viewModel.fetchGroupsData();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChange);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelChange() {
    setState(() {});
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);
    try {
      await _reportService.generateGroupsSchedulesReport(
        groupsData: _viewModel.groupsData,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Groups & Schedules report generated successfully!')),
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
        title: const Text('Groups & Schedules', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _viewModel.isLoading || _isGenerating ? null : _generateReport,
            tooltip: 'Export as PDF',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.cosmicGradient,
        ),
        child: SafeArea(
          child: Stack(
        children: [
          _viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      'Group Settings & Timings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Overview of all active and inactive schedules.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ..._viewModel.groupsData.map((group) {
                      final isActive = group['is_active'] == true;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isActive ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                  child: Icon(
                                    isActive ? Icons.check_circle : Icons.cancel,
                                    color: isActive ? Colors.green : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group['group_name'] ?? '',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Timing: ${group['timing']}',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      Text(
                                        'Teacher: ${group['teacher']}',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isActive ? Colors.green : Colors.red),
                                  ),
                                  child: Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: isActive ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
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
        ),
      ),
    );
  }
}
