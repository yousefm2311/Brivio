import 'package:flutter/material.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../domain/models/attendance_models.dart';
import '../viewmodels/fast_attendance_viewmodel.dart';

class FastAttendanceScreen extends StatefulWidget {
  const FastAttendanceScreen({super.key});

  @override
  State<FastAttendanceScreen> createState() => _FastAttendanceScreenState();
}

class _FastAttendanceScreenState extends State<FastAttendanceScreen> {
  final FastAttendanceViewModel _viewModel = FastAttendanceViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChange);
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

  void _showIncidentDialog(FastAttendanceStudent student) {
    final controller = TextEditingController(text: student.incidentRecord);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.darkSurface,
          title: Text(
            'Log Incident for ${student.name}',
            style: AppTypography.titleLarge(AppColors.darkTextPrimary),
          ),
          content: TextField(
            controller: controller,
            style: AppTypography.bodyMedium(AppColors.darkTextPrimary),
            decoration: InputDecoration(
              hintText: 'Describe the behavior...',
              hintStyle: AppTypography.bodyMedium(AppColors.darkTextSecondary),
              filled: true,
              fillColor: AppColors.darkSurfaceSecondary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: AppTypography.labelLarge(AppColors.darkTextSecondary),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _viewModel.logIncident(student.id, controller.text.trim());
                Navigator.pop(context);
              },
              child: Text(
                'Save',
                style: AppTypography.labelLarge(Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text(
          'Fast Attendance',
          style: AppTypography.titleLarge(AppColors.darkTextPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Swipe right for Present, left for Absent',
                style: AppTypography.bodyMedium(AppColors.darkTextSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _viewModel.students.length,
                  itemBuilder: (context, index) {
                    final student = _viewModel.students[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Dismissible(
                        key: ValueKey(student.id),
                        background: Container(
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        secondaryBackground: Container(
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            _viewModel.markAttendance(
                              student.id,
                              AttendanceStatus.present,
                            );
                          } else if (direction == DismissDirection.endToStart) {
                            _viewModel.markAttendance(
                              student.id,
                              AttendanceStatus.absent,
                            );
                          }
                          return false; // Don't actually remove from the list
                        },
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primarySubtle,
                                radius: 22,
                                child: Text(
                                  student.name.isNotEmpty
                                      ? student.name
                                            .substring(0, 1)
                                            .toUpperCase()
                                      : '?',
                                  style: AppTypography.titleMedium(
                                    AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.titleMedium(
                                        AppColors.darkTextPrimary,
                                      ),
                                    ),
                                    if (student.incidentRecord != null &&
                                        student.incidentRecord!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Incident: ${student.incidentRecord}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodySmall(
                                            AppColors.error,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (student.status != null)
                                          _AttendanceStatusPill(
                                            status: student.status!,
                                          ),
                                        Tooltip(
                                          message: 'Log Incident',
                                          child: IconButton.filledTonal(
                                            visualDensity:
                                                VisualDensity.compact,
                                            icon: const Icon(
                                              Icons.warning_amber_rounded,
                                            ),
                                            color: AppColors.warning,
                                            onPressed: () =>
                                                _showIncidentDialog(student),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _viewModel.isLoading
                    ? null
                    : () async {
                        await _viewModel.submitAttendance();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Attendance submitted!',
                                style: AppTypography.bodyMedium(Colors.white),
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          Navigator.pop(context);
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _viewModel.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Submit Attendance',
                        style: AppTypography.labelLarge(Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceStatusPill extends StatelessWidget {
  final AttendanceStatus status;

  const _AttendanceStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPresent = status == AttendanceStatus.present;
    final color = isPresent ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPresent ? AppColors.successSubtle : AppColors.errorSubtle,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isPresent ? 'Present' : 'Absent',
        style: AppTypography.labelMedium(color),
      ),
    );
  }
}
