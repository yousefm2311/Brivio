import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class TeacherHomeworkScreen extends StatefulWidget {
  final String teacherId;

  const TeacherHomeworkScreen({super.key, required this.teacherId});

  @override
  State<TeacherHomeworkScreen> createState() => _TeacherHomeworkScreenState();
}

class _TeacherHomeworkScreenState extends State<TeacherHomeworkScreen> {
  late final SupabaseHomeworkRepository _homeworkRepo;
  late final SupabaseTeacherRepository _teacherRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Homework> _homeworks = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _homeworkRepo = SupabaseHomeworkRepository(wrapper);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _loadGroupsAndHomeworks();
  }

  Future<void> _loadGroupsAndHomeworks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      GroupEntity? selected;
      if (_selectedGroup == null) {
        selected = groups.isNotEmpty ? groups.first : null;
      } else {
        for (final group in groups) {
          if (group.id == _selectedGroup!.id) {
            selected = group;
            break;
          }
        }
      }
      final homeworks = selected == null
          ? <Homework>[]
          : await _homeworkRepo.fetchHomeworkForGroup(selected.id);

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _homeworks = homeworks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectGroup(GroupEntity? group) async {
    setState(() => _selectedGroup = group);
    await _loadGroupsAndHomeworks();
  }

  void _showCreateHomeworkDialog() {
    final group = _selectedGroup;
    if (group == null) return;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ptsCtrl = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${context.tr('Create Homework for')} ${group.name}',
                    style: AppTypography.displaySmall(textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(labelText: context.tr('Homework title')),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(labelText: context.tr('Instructions')),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ptsCtrl,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(labelText: context.tr('Max score')),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(context.tr('Cancel'), style: TextStyle(color: textColor)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          if (titleCtrl.text.trim().isEmpty) return;
                          final nav = Navigator.of(ctx);
                          try {
                            await Supabase.instance.client.rpc(
                              'create_homework_assignment',
                              params: {
                                'p_title': titleCtrl.text.trim(),
                                'p_description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                                'p_subject_id': group.subjectId,
                                'p_group_id': group.id,
                                'p_due_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
                                'p_max_score': double.tryParse(ptsCtrl.text) ?? 100.0,
                                'p_status': 'published',
                              },
                            );
                            nav.pop();
                            await _loadGroupsAndHomeworks();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.tr('Homework published.')), backgroundColor: Colors.green),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${context.tr('Creation failed')}: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                        child: Text(context.tr('Publish')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtitleColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadGroupsAndHomeworks,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${context.tr('Error')}: $_errorMessage', style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loadGroupsAndHomeworks,
                                child: Text(context.tr('Retry')),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              child: DropdownButtonFormField<GroupEntity>(
                                initialValue: _selectedGroup,
                                dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                                decoration: InputDecoration(
                                  labelText: context.tr('Assigned group'),
                                  border: InputBorder.none,
                                ),
                                items: _groups.map((g) => DropdownMenuItem(value: g, child: Text(g.name, style: TextStyle(color: textColor)))).toList(),
                                onChanged: _groups.isEmpty ? null : _selectGroup,
                              ),
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        if (_selectedGroup == null)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(context.tr('No assigned groups found.'), style: AppTypography.bodyMedium(subtitleColor)),
                            ),
                          )
                        else if (_homeworks.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(context.tr('No homework assignments published yet.'), style: AppTypography.bodyMedium(subtitleColor)),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                                  final h = _homeworks[i];
                                  return FadeInSlide(
                                    duration: Duration(milliseconds: 300 + (i * 50)),
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: GlassCard(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                              child: const Icon(Icons.assignment, color: AppColors.primary),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    h.title,
                                                    style: AppTypography.titleMedium(textColor).copyWith(fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${context.tr('Max Score')}: ${h.maxScore} | ${context.tr('Due')}: ${h.dueAt.year}-${h.dueAt.month}-${h.dueAt.day} | ${context.tr('Status')}: ${context.tr(h.status)}',
                                                    style: AppTypography.caption(subtitleColor),
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
                                childCount: _homeworks.length,
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
        if (_selectedGroup != null)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _showCreateHomeworkDialog,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.assignment),
              label: Text(context.tr('Create Homework')),
            ),
          ),
      ],
    );
  }
}
