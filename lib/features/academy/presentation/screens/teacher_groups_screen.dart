import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';
import 'teacher_group_details_screen.dart';

class TeacherGroupsScreen extends StatefulWidget {
  final String teacherId;

  const TeacherGroupsScreen({super.key, required this.teacherId});

  @override
  State<TeacherGroupsScreen> createState() => _TeacherGroupsScreenState();
}

class _TeacherGroupsScreenState extends State<TeacherGroupsScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  List<GroupEntity> _groups = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      if (mounted) {
        setState(() {
          _groups = res;
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

  void _openGroupDetails(GroupEntity group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherGroupDetailsScreen(group: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtitleColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return RefreshIndicator(
      onRefresh: _loadGroups,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: $_errorMessage',
                          style: AppTypography.bodyMedium(AppColors.error),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadGroups,
                          child: Text('Retry', style: AppTypography.labelMedium(textColor)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : _groups.isEmpty
          ? CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No groups currently assigned to you.',
                      style: AppTypography.bodyMedium(subtitleColor),
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _groups.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final g = _groups[i];
                return FadeInSlide(
                  delay: Duration(milliseconds: 50 * i),
                  child: GlassCard(
                    color: surfaceColor,
                    onTap: () => _openGroupDetails(g),
                    child: Row(
                      children: [
                        const CircleIcon(
                          icon: Icons.group,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.name,
                                style: AppTypography.titleMedium(textColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Code: ${g.code} | Capacity: ${g.maxCapacity ?? "Unlimited"}',
                                style: AppTypography.bodySmall(subtitleColor),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: subtitleColor),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
