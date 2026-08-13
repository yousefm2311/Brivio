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
  late final SupabaseQuestionBankRepository _questionRepo;
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
    _questionRepo = SupabaseQuestionBankRepository(wrapper);
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
    DateTime? availableFrom;
    DateTime dueAt = DateTime.now().add(const Duration(days: 7));

    Future<DateTime?> pickDateTime(DateTime initial) async {
      final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (date == null || !mounted) return null;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null) return null;
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => Dialog(
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
                      decoration: InputDecoration(
                        labelText: context.tr('Homework title'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: context.tr('Instructions'),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ptsCtrl,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: context.tr('Max score'),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(context.tr('Opens at')),
                      subtitle: Text(
                        availableFrom == null
                            ? context.tr('Immediately')
                            : availableFrom!.toLocal().toString(),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await pickDateTime(
                            availableFrom ?? DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => availableFrom = picked);
                          }
                        },
                        child: Text(context.tr('Set')),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_clock),
                      title: Text(context.tr('Closes at')),
                      subtitle: Text(dueAt.toLocal().toString()),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await pickDateTime(dueAt);
                          if (picked != null) {
                            setDialogState(() => dueAt = picked);
                          }
                        },
                        child: Text(context.tr('Set')),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            context.tr('Cancel'),
                            style: TextStyle(color: textColor),
                          ),
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
                              await _homeworkRepo.createHomework(
                                Homework(
                                  id: '',
                                  title: titleCtrl.text.trim(),
                                  description: descCtrl.text.trim().isEmpty
                                      ? null
                                      : descCtrl.text.trim(),
                                  subjectId: group.subjectId,
                                  groupId: group.id,
                                  availableFrom: availableFrom,
                                  dueAt: dueAt,
                                  maxScore:
                                      double.tryParse(ptsCtrl.text) ?? 100.0,
                                  status: 'published',
                                ),
                              );
                              nav.pop();
                              await _loadGroupsAndHomeworks();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.tr('Homework published.'),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${context.tr('Creation failed')}: $e',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
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
          ),
        );
      },
    );
  }

  void _showManageQuestionsBottomSheet(Homework homework) async {
    final group = _selectedGroup;
    if (group == null) return;

    final Set<String> initiallyLinkedIds = homework.questions
        .map((q) => q.id)
        .toSet();
    final Set<String> currentSelectedIds = Set<String>.from(initiallyLinkedIds);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
        final textColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: FutureBuilder<List<Question>>(
                future: _questionRepo.fetchQuestionsForSubject(group.subjectId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading questions: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final allQuestions = snapshot.data ?? [];
                  if (allQuestions.isEmpty) {
                    return Center(
                      child: Text(
                        context.tr('No questions found in Question Bank.'),
                        style: TextStyle(color: textColor),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          '${context.tr('Manage Questions for')} ${homework.title}',
                          style: AppTypography.displaySmall(textColor),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${currentSelectedIds.length} ${context.tr('Selected')}',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  if (currentSelectedIds.length ==
                                      allQuestions.length) {
                                    currentSelectedIds.clear();
                                  } else {
                                    currentSelectedIds.addAll(
                                      allQuestions.map((q) => q.id),
                                    );
                                  }
                                });
                              },
                              child: Text(
                                currentSelectedIds.length == allQuestions.length
                                    ? context.tr('Deselect All')
                                    : context.tr('Select All'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: allQuestions.length,
                          itemBuilder: (context, index) {
                            final q = allQuestions[index];
                            final isLinked = currentSelectedIds.contains(q.id);

                            return ListTile(
                              title: Text(
                                q.prompt,
                                style: TextStyle(color: textColor),
                              ),
                              subtitle: Text(
                                '${context.tr(q.questionType.name)} | ${q.defaultPoints} ${context.tr('pts')}',
                              ),
                              trailing: Checkbox(
                                value: isLinked,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  if (val == null) return;
                                  setModalState(() {
                                    if (val) {
                                      currentSelectedIds.add(q.id);
                                    } else {
                                      currentSelectedIds.remove(q.id);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setModalState(() => isSaving = true);
                                  try {
                                    final additions = currentSelectedIds
                                        .difference(initiallyLinkedIds);
                                    final removals = initiallyLinkedIds
                                        .difference(currentSelectedIds);

                                    for (final id in additions) {
                                      final q = allQuestions.firstWhere(
                                        (q) => q.id == id,
                                      );
                                      await _homeworkRepo.linkQuestion(
                                        homework.id,
                                        q.id,
                                        q.defaultPoints,
                                      );
                                    }
                                    for (final id in removals) {
                                      await _homeworkRepo.unlinkQuestion(
                                        homework.id,
                                        id,
                                      );
                                    }

                                    await _loadGroupsAndHomeworks();
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (ctx.mounted) {
                                      setModalState(() => isSaving = false);
                                    }
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(context.tr('Save & Close')),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteHomework(Homework homework) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete Homework')),
        content: Text(context.tr('Delete this homework and its submissions?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _homeworkRepo.deleteHomework(homework.id);
      await _loadGroupsAndHomeworks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('Delete failed')}: $e')),
      );
    }
  }

  Future<void> _closeHomework(Homework homework) async {
    if (homework.status == 'closed') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Close Homework')),
        content: Text(
          context.tr(
            'Students will no longer be able to submit this homework.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Close')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _homeworkRepo.closeHomework(homework.id);
      await _loadGroupsAndHomeworks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('Close failed')}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final subtitleColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

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
                          Text(
                            '${context.tr('Error')}: $_errorMessage',
                            style: const TextStyle(color: Colors.red),
                          ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 4.0,
                          ),
                          child: DropdownButtonFormField<GroupEntity>(
                            initialValue: _selectedGroup,
                            dropdownColor: isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                            decoration: InputDecoration(
                              labelText: context.tr('Assigned group'),
                              border: InputBorder.none,
                            ),
                            items: _groups
                                .map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(
                                      g.name,
                                      style: TextStyle(color: textColor),
                                    ),
                                  ),
                                )
                                .toList(),
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
                          child: Text(
                            context.tr('No assigned groups found.'),
                            style: AppTypography.bodyMedium(subtitleColor),
                          ),
                        ),
                      )
                    else if (_homeworks.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            context.tr(
                              'No homework assignments published yet.',
                            ),
                            style: AppTypography.bodyMedium(subtitleColor),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((ctx, i) {
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
                                        backgroundColor: AppColors.primary
                                            .withValues(alpha: 0.2),
                                        child: const Icon(
                                          Icons.assignment,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              h.title,
                                              style:
                                                  AppTypography.titleMedium(
                                                    textColor,
                                                  ).copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${context.tr('Due')}: ${h.dueAt.toLocal().toString().split(' ')[0]} | ${context.tr('Status')}: ${context.tr(h.status)}',
                                              style: AppTypography.caption(
                                                subtitleColor,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${h.questions.length} ${context.tr('Questions')}',
                                              style: AppTypography.caption(
                                                AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_document,
                                          color: AppColors.primary,
                                        ),
                                        tooltip: context.tr('Manage Questions'),
                                        onPressed: () =>
                                            _showManageQuestionsBottomSheet(h),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.lock_outline,
                                          color: AppColors.warning,
                                        ),
                                        tooltip: context.tr('Close Homework'),
                                        onPressed: h.status == 'closed'
                                            ? null
                                            : () => _closeHomework(h),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.error,
                                        ),
                                        tooltip: context.tr('Delete Homework'),
                                        onPressed: () => _deleteHomework(h),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }, childCount: _homeworks.length),
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
