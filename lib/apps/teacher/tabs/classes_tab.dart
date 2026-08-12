import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/components/glass_card.dart';
import '../screens/class_roster_screen.dart';
import '../viewmodels/classes_viewmodel.dart';

class ClassesTab extends StatefulWidget {
  final String teacherId;

  const ClassesTab({super.key, required this.teacherId});

  @override
  State<ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<ClassesTab> {
  late final ClassesViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ClassesViewModel()..loadClasses();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Container(
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Text(
              context.tr('My Classes'),
              style: AppTypography.displaySmall(textPrimary).copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _viewModel,
              builder: (context, child) {
                if (_viewModel.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_viewModel.classes.isEmpty) {
                  return Center(
                    child: Text(
                      'No classes assigned.',
                      style: AppTypography.bodyLarge(textSecondary),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: _viewModel.classes.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final tClass = _viewModel.classes[index];
                    return GlassCard(
                      color: surfaceColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClassRosterScreen(teacherClass: tClass),
                          ),
                        );
                      },
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.class_,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tClass.name,
                                  style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 14, color: textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      tClass.time,
                                      style: AppTypography.bodySmall(textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.people, size: 14, color: textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${tClass.students.length} Students',
                                      style: AppTypography.bodySmall(textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: textSecondary),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
