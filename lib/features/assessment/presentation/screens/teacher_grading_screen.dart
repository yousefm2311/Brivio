import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class TeacherGradingScreen extends StatefulWidget {
  final String teacherId;

  const TeacherGradingScreen({super.key, required this.teacherId});

  @override
  State<TeacherGradingScreen> createState() => _TeacherGradingScreenState();
}

class _TeacherGradingScreenState extends State<TeacherGradingScreen> {
  List<Map<String, dynamic>> _homeworkSubmissions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGradingQueue();
  }

  Future<void> _loadGradingQueue() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await Supabase.instance.client.rpc(
        'get_teacher_grading_queue',
        params: {'p_teacher_id': widget.teacherId},
      );

      if (mounted) {
        setState(() {
          _homeworkSubmissions = (res as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
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

  void _showGradeSubmissionDialog(Map<String, dynamic> submission) {
    final scoreCtrl = TextEditingController(text: '95');
    final feedbackCtrl = TextEditingController(text: 'Excellent solution!');

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
                    context.tr('Manual Grading & Feedback'),
                    style: AppTypography.displaySmall(textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: scoreCtrl,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(labelText: context.tr('Final Score')),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: feedbackCtrl,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(labelText: context.tr('Teacher Feedback')),
                    maxLines: 2,
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
                          final nav = Navigator.of(ctx);
                          final score = double.tryParse(scoreCtrl.text) ?? 90.0;
                          try {
                            await Supabase.instance.client.rpc(
                              'grade_homework_submission',
                              params: {
                                'p_submission_id': submission['id'],
                                'p_score': score,
                                'p_feedback': feedbackCtrl.text.trim().isEmpty ? null : feedbackCtrl.text.trim(),
                              },
                            );

                            nav.pop();
                            _loadGradingQueue();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.tr('Grade & feedback submitted to student!')),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${context.tr('Grading failed')}: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: Text(context.tr('Submit Grade')),
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

    return RefreshIndicator(
      onRefresh: _loadGradingQueue,
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
                            onPressed: _loadGradingQueue,
                            child: Text(context.tr('Retry')),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : _homeworkSubmissions.isEmpty
                  ? CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              context.tr('No pending submissions requiring manual grading.'),
                              style: AppTypography.bodyMedium(subtitleColor),
                            ),
                          ),
                        ),
                      ],
                    )
                  : CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final sub = _homeworkSubmissions[i];
                                final isGraded = sub['status'] == 'graded';

                                return FadeInSlide(
                                  duration: Duration(milliseconds: 300 + (i * 50)),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: GlassCard(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: isGraded ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                                            child: Icon(Icons.grading, color: isGraded ? Colors.green : Colors.orange),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${context.tr('Student')}: ${sub['student_full_name'] ?? context.tr("Learner")}',
                                                  style: AppTypography.titleMedium(textColor).copyWith(fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${sub['homework_title'] ?? context.tr("Homework")} | ${context.tr('Status')}: ${context.tr((sub['status'] as String? ?? "submitted"))} | ${context.tr('Score')}: ${sub['score'] ?? context.tr("Pending")}',
                                                  style: AppTypography.caption(subtitleColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          isGraded
                                              ? Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    context.tr('graded'),
                                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                )
                                              : ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors.primary,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                  onPressed: () => _showGradeSubmissionDialog(sub),
                                                  child: Text(context.tr('Grade')),
                                                ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: _homeworkSubmissions.length,
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
