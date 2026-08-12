import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../student_dashboard_models.dart';

String _formatDate(DateTime? dt) =>
    dt == null ? '' : DateFormat.yMMMd().format(dt);
String _formatTime(DateTime? dt) =>
    dt == null ? '' : DateFormat.jm().format(dt);

Color _attendanceColor(String status) {
  switch (status) {
    case 'present':
      return AppColors.success;
    case 'late':
      return AppColors.warning;
    case 'absent':
      return AppColors.error;
    case 'excused':
      return AppColors.info;
    default:
      return AppColors.darkBorder;
  }
}

IconData _attendanceIcon(String status) {
  switch (status) {
    case 'present':
      return Icons.check_circle_rounded;
    case 'late':
      return Icons.schedule_rounded;
    case 'absent':
      return Icons.cancel_rounded;
    case 'excused':
      return Icons.event_available_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}

Color _leaveColor(String status) {
  switch (status) {
    case 'approved':
      return AppColors.success;
    case 'rejected':
      return AppColors.error;
    default:
      return AppColors.warning;
  }
}

class ActivityTab extends StatefulWidget {
  final bool isLoading;
  final List<StudentHomeworkItem> homeworkItems;
  final List<StudentExamItem> examItems;
  final List<StudentAttendanceItem> attendanceItems;
  final List<StudentLeaveItem> leaveItems;
  final List<PublishedSessionBoard> sessionBoards;
  final ValueChanged<StudentHomeworkItem> onSubmitHomework;
  final ValueChanged<StudentExamItem> onStartExam;
  final VoidCallback onCreateLeaveRequest;
  final VoidCallback onScanQr;
  final ValueChanged<PublishedSessionBoard> onOpenBoard;

  const ActivityTab({
    super.key,
    required this.isLoading,
    required this.homeworkItems,
    required this.examItems,
    required this.attendanceItems,
    required this.leaveItems,
    required this.sessionBoards,
    required this.onSubmitHomework,
    required this.onStartExam,
    required this.onCreateLeaveRequest,
    required this.onScanQr,
    required this.onOpenBoard,
  });

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final bgColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Column(
      children: [
        // ── Header ──
        Container(
          color: bgColor,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInSlide(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  context.tr('Activity'),
                  style: AppTypography.displaySmall(textPrimary).copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ── Tab bar ──
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 100),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: textPrimary,
                    unselectedLabelColor: textPrimary.withValues(alpha: 0.5),
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    tabs: [
                      Tab(
                        text:
                            '${context.tr('Homework')} & ${context.tr('Exams')}',
                      ),
                      Tab(text: context.tr('Attendance')),
                      Tab(text: context.tr('Boards')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // ── Tab views ──
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _HomeworkAndExamsView(
                isLoading: widget.isLoading,
                homeworkItems: widget.homeworkItems,
                examItems: widget.examItems,
                onSubmitHomework: widget.onSubmitHomework,
                onStartExam: widget.onStartExam,
              ),
              _AttendanceView(
                isLoading: widget.isLoading,
                attendanceItems: widget.attendanceItems,
                leaveItems: widget.leaveItems,
                onCreateLeaveRequest: widget.onCreateLeaveRequest,
                onScanQr: widget.onScanQr,
              ),
              _SessionBoardsSection(
                isLoading: widget.isLoading,
                boards: widget.sessionBoards,
                onOpenBoard: widget.onOpenBoard,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: AppTypography.titleMedium(
          color,
        ).copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      ),
    );
  }
}

class _AppleGroupedList extends StatelessWidget {
  final List<Widget> children;

  const _AppleGroupedList({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return GlassCard(
      color: surfaceColor,
      borderColor: borderColor,
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: children.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: borderColor, indent: 64),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class _InlinePlaceholder extends StatelessWidget {
  final String text;
  const _InlinePlaceholder({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          style: AppTypography.bodyMedium(
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }
}

Future<void> _showAssessmentReviewDialog(
  BuildContext context, {
  required String rpcName,
  required Map<String, dynamic> params,
}) async {
  var loaderVisible = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  late final dynamic raw;
  try {
    raw = await Supabase.instance.client.rpc(rpcName, params: params);
  } catch (_) {
    if (context.mounted && loaderVisible) {
      Navigator.of(context).pop();
    }
    rethrow;
  }

  if (!context.mounted) return;
  Navigator.of(context).pop();
  loaderVisible = false;

  final review = Map<String, dynamic>.from(raw as Map);
  final released = review['released'] == true;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textPrimary = isDark
      ? AppColors.darkTextPrimary
      : AppColors.lightTextPrimary;
  final textSecondary = isDark
      ? AppColors.darkTextSecondary
      : AppColors.lightTextSecondary;
  final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;
  final answers = (review['answers'] as List<dynamic>? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: surfaceColor,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: released
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['title']?.toString() ?? context.tr('Review'),
                      style: AppTypography.titleLarge(
                        textPrimary,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.tr('Score')}: ${review['score'] ?? 0} / ${review['max_score'] ?? 0}',
                      style: AppTypography.titleMedium(
                        AppColors.primary,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    if ((review['teacher_feedback']?.toString() ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${context.tr('Teacher Feedback')}: ${review['teacher_feedback']}',
                        style: AppTypography.bodyMedium(textSecondary),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.48,
                      child: answers.isEmpty
                          ? Center(
                              child: Text(
                                context.tr('No answers provided.'),
                                style: AppTypography.bodyMedium(textSecondary),
                              ),
                            )
                          : ListView.separated(
                              itemCount: answers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, index) {
                                final answer = answers[index];
                                final isCorrect = answer['is_correct'] == true;
                                final color = isCorrect
                                    ? AppColors.success
                                    : AppColors.error;
                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.08),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.5),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              isCorrect
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              color: color,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                answer['prompt']?.toString() ??
                                                    '',
                                                style:
                                                    AppTypography.bodyMedium(
                                                      textPrimary,
                                                    ).copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${context.tr('Your Answer')}: ${answer['student_answer'] ?? context.tr('No Answer')}',
                                          style: AppTypography.bodyMedium(
                                            textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${context.tr('Correct Answer')}: ${answer['correct_answer'] ?? 'N/A'}',
                                          style:
                                              AppTypography.bodyMedium(
                                                AppColors.success,
                                              ).copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        if ((answer['explanation']
                                                    ?.toString() ??
                                                '')
                                            .trim()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '${context.tr('Explanation')}: ${answer['explanation']}',
                                            style: AppTypography.caption(
                                              textSecondary,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          '${context.tr('Points')}: ${answer['points_awarded'] ?? 0} / ${answer['max_points'] ?? 0}',
                                          style:
                                              AppTypography.caption(
                                                textSecondary,
                                              ).copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(context.tr('Close')),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_clock, size: 44),
                    const SizedBox(height: 12),
                    Text(
                      review['message']?.toString() ??
                          context.tr('Results are not released yet'),
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium(textPrimary),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(context.tr('Close')),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}

class _HomeworkAndExamsView extends StatelessWidget {
  final bool isLoading;
  final List<StudentHomeworkItem> homeworkItems;
  final List<StudentExamItem> examItems;
  final ValueChanged<StudentHomeworkItem> onSubmitHomework;
  final ValueChanged<StudentExamItem> onStartExam;

  const _HomeworkAndExamsView({
    required this.isLoading,
    required this.homeworkItems,
    required this.examItems,
    required this.onSubmitHomework,
    required this.onStartExam,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (homeworkItems.isEmpty && examItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_turned_in_rounded,
              size: 64,
              color: AppColors.success.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('All clear!'),
              style: AppTypography.titleLarge(
                textPrimary,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Published homework and exams will appear here.'),
              style: AppTypography.bodyMedium(
                isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        if (homeworkItems.isNotEmpty) ...[
          FadeInSlide(
            duration: const Duration(milliseconds: 500),
            child: _SectionLabel(
              text: context.tr('Homework'),
              color: textPrimary,
            ),
          ),
          FadeInSlide(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 100),
            child: _AppleGroupedList(
              children: homeworkItems
                  .map(
                    (item) => _HomeworkTile(
                      item: item,
                      onSubmit: () => onSubmitHomework(item),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (examItems.isNotEmpty) ...[
          FadeInSlide(
            duration: const Duration(milliseconds: 500),
            delay: const Duration(milliseconds: 200),
            child: _SectionLabel(
              text: context.tr('Exams & Quizzes'),
              color: textPrimary,
            ),
          ),
          FadeInSlide(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 300),
            child: _AppleGroupedList(
              children: examItems
                  .map(
                    (item) =>
                        _ExamTile(item: item, onStart: () => onStartExam(item)),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeworkTile extends StatelessWidget {
  final StudentHomeworkItem item;
  final VoidCallback onSubmit;

  const _HomeworkTile({required this.item, required this.onSubmit});

  void _showGradedDetailsDialog(
    BuildContext context,
    StudentHomeworkItem item,
  ) async {
    try {
      await _showAssessmentReviewDialog(
        context,
        rpcName: 'get_my_homework_review',
        params: {'p_homework_id': item.homework.id},
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('Failed to load review')}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final statusColor = item.isGraded
        ? AppColors.success
        : item.isSubmitted
        ? AppColors.info
        : AppColors.warning;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.isSubmitted || item.isGraded
            ? () => _showGradedDetailsDialog(context, item)
            : onSubmit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.isGraded
                      ? Icons.assignment_turned_in_rounded
                      : Icons.assignment_rounded,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.homework.title,
                      style: AppTypography.bodyMedium(
                        textPrimary,
                      ).copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.groupName}  ·  Due ${_formatDate(item.homework.dueAt)}',
                      style: AppTypography.caption(
                        textSecondary,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PortalStatusChip(status: item.submissionStatus ?? 'pending'),
                  if (item.isSubmitted || item.isGraded) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.tr('Review'),
                      style: AppTypography.caption(
                        AppColors.primary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(
                      context.tr('Submit'),
                      style: AppTypography.caption(
                        AppColors.primary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamTile extends StatelessWidget {
  final StudentExamItem item;
  final VoidCallback onStart;

  const _ExamTile({required this.item, required this.onStart});

  Future<void> _showExamReview(BuildContext context) async {
    try {
      await _showAssessmentReviewDialog(
        context,
        rpcName: 'get_my_exam_review',
        params: {'p_exam_id': item.exam.id},
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('Failed to load review')}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final accentColor = item.canStart ? AppColors.studentRole : AppColors.info;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.canStart
            ? onStart
            : item.canReview
            ? () => _showExamReview(context)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.quiz_rounded, color: accentColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.exam.title,
                      style: AppTypography.bodyMedium(
                        textPrimary,
                      ).copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.groupName}  ·  ${item.exam.durationMinutes} min  ·  ${item.attemptCount}/${item.exam.maxAttempts} attempts',
                      style: AppTypography.caption(
                        textSecondary,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PortalStatusChip(
                    status: item.lastAttemptStatus ?? item.exam.status,
                  ),
                  if (item.canStart) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.tr('Start'),
                      style: AppTypography.caption(
                        AppColors.primary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ] else if (item.canReview) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.tr('Review'),
                      style: AppTypography.caption(
                        AppColors.primary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceView extends StatelessWidget {
  final bool isLoading;
  final List<StudentAttendanceItem> attendanceItems;
  final List<StudentLeaveItem> leaveItems;
  final VoidCallback onCreateLeaveRequest;
  final VoidCallback onScanQr;

  const _AttendanceView({
    required this.isLoading,
    required this.attendanceItems,
    required this.leaveItems,
    required this.onCreateLeaveRequest,
    required this.onScanQr,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final total = attendanceItems.length;
    final present = attendanceItems.where((i) => i.status == 'present').length;
    final late = attendanceItems.where((i) => i.status == 'late').length;
    final absent = attendanceItems.where((i) => i.status == 'absent').length;
    final excused = attendanceItems.where((i) => i.status == 'excused').length;
    final rate = total == 0
        ? 100
        : (((present + late + excused) / total) * 100).round();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // ── Action buttons ──
        FadeInSlide(
          duration: const Duration(milliseconds: 500),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onScanQr,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: Text(
                    context.tr('Scan QR'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCreateLeaveRequest,
                  icon: const Icon(Icons.event_busy_rounded, size: 20),
                  label: Text(
                    context.tr('Request Leave'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Stats ──
        FadeInSlide(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 100),
          child: PortalMetricGrid(
            children: [
              PortalMetricCard(
                label: context.tr('Rate'),
                value: '$rate%',
                icon: Icons.insights_rounded,
                accentColor: AppColors.studentRole,
              ),
              PortalMetricCard(
                label: context.tr('Present'),
                value: '$present',
                icon: Icons.check_circle_rounded,
                accentColor: AppColors.success,
              ),
              PortalMetricCard(
                label: context.tr('Late'),
                value: '$late',
                icon: Icons.schedule_rounded,
                accentColor: AppColors.warning,
              ),
              PortalMetricCard(
                label: context.tr('Absent'),
                value: '$absent',
                icon: Icons.cancel_rounded,
                accentColor: AppColors.error,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── History ──
        if (attendanceItems.isNotEmpty) ...[
          FadeInSlide(
            duration: const Duration(milliseconds: 500),
            delay: const Duration(milliseconds: 200),
            child: _SectionLabel(
              text: context.tr('Attendance History'),
              color: textPrimary,
            ),
          ),
          FadeInSlide(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 300),
            child: _AppleGroupedList(
              children: attendanceItems
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _attendanceColor(
                                item.status,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _attendanceIcon(item.status),
                              color: _attendanceColor(item.status),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_formatDate(item.sessionDate)}  ·  ${item.groupName}',
                                  style: AppTypography.bodyMedium(
                                    textPrimary,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatTime(item.scheduledStartAt)} – ${_formatTime(item.scheduledEndAt)}',
                                  style: AppTypography.caption(
                                    textSecondary,
                                  ).copyWith(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          PortalStatusChip(status: item.status),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 28),
        ],

        // ── Leave requests ──
        FadeInSlide(
          duration: const Duration(milliseconds: 500),
          delay: const Duration(milliseconds: 400),
          child: _SectionLabel(
            text:
                '${context.tr("Leave Requests")}  ·  $excused ${context.tr("Excused")}',
            color: textPrimary,
          ),
        ),
        FadeInSlide(
          duration: const Duration(milliseconds: 600),
          delay: const Duration(milliseconds: 500),
          child: leaveItems.isEmpty
              ? _InlinePlaceholder(
                  text: context.tr('No leave requests submitted yet.'),
                )
              : _AppleGroupedList(
                  children: leaveItems
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _leaveColor(
                                    item.status,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.event_busy_rounded,
                                  color: _leaveColor(item.status),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.classSessionId == null
                                          ? context.tr('General leave request')
                                          : '${_formatDate(item.sessionDate ?? item.submittedAt)}  ·  ${item.groupName}',
                                      style: AppTypography.bodyMedium(
                                        textPrimary,
                                      ).copyWith(fontWeight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.reason,
                                      style: AppTypography.caption(
                                        textSecondary,
                                      ).copyWith(fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              PortalStatusChip(status: item.status),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _SessionBoardsSection extends StatelessWidget {
  final bool isLoading;
  final List<PublishedSessionBoard> boards;
  final ValueChanged<PublishedSessionBoard> onOpenBoard;

  const _SessionBoardsSection({
    required this.isLoading,
    required this.boards,
    required this.onOpenBoard,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (boards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.draw_rounded,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('No boards yet'),
              style: AppTypography.titleLarge(
                textPrimary,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Boards appear after your teacher publishes a session board.',
              ),
              style: AppTypography.bodyMedium(
                isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        FadeInSlide(
          duration: const Duration(milliseconds: 600),
          child: _AppleGroupedList(
            children: boards
                .map(
                  (board) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onOpenBoard(board),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.draw_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    board.title,
                                    style: AppTypography.bodyMedium(
                                      textPrimary,
                                    ).copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${board.groupName}  ·  ${_formatDate(board.sessionDate)}',
                                    style: AppTypography.caption(
                                      textSecondary,
                                    ).copyWith(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: AppColors.primary,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
