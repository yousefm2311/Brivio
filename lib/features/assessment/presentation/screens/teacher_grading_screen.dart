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
  List<Map<String, dynamic>> _resetRequests = [];
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
      
      final resetsRes = await Supabase.instance.client
          .from('exam_reset_requests')
          .select('*, exams(title), students(profiles(full_name))')
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _homeworkSubmissions = (res as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _resetRequests = (resetsRes as List<dynamic>)
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

  void _handleResetRequest(Map<String, dynamic> req, bool approve) async {
    try {
      if (approve) {
        await Supabase.instance.client.rpc(
          'reset_student_exam_attempt',
          params: {
            'p_student_id': req['student_id'],
            'p_exam_id': req['exam_id'],
          },
        );
      }
      
      await Supabase.instance.client.from('exam_reset_requests').update({
        'status': approve ? 'approved' : 'rejected',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', req['id']);
      
      _loadGradingQueue();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve ? context.tr('Exam reset approved.') : context.tr('Reset request rejected.')),
          backgroundColor: approve ? Colors.green : Colors.orange,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showGradeSubmissionDialog(Map<String, dynamic> submission) async {
    final scoreCtrl = TextEditingController(text: submission['score']?.toString() ?? '95');
    final feedbackCtrl = TextEditingController(text: 'Excellent solution!');

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    List<Map<String, dynamic>> answers = [];
    try {
      final isExam = submission['assessment_type'] == 'exam';
      final table = isExam ? 'exam_answers' : 'homework_answers';
      final foreignKey = isExam ? 'attempt_id' : 'submission_id';
      
      final res = await Supabase.instance.client
          .from(table)
          .select('*, questions(*), question_options(*)')
          .eq(foreignKey, submission['id']);
      answers = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Failed to fetch answers: $e');
    }

    if (!mounted) return;
    Navigator.pop(context); // Dismiss loading indicator

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        final subtitleColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      context.tr('Manual Grading & Feedback'),
                      style: AppTypography.displaySmall(textColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (submission['submission_text'] != null || submission['attachment_url'] != null) ...[
                    Text(context.tr('Student Submission:'), style: AppTypography.titleMedium(textColor).copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (submission['submission_text'] != null && submission['submission_text'].toString().isNotEmpty)
                            Text(
                              submission['submission_text'],
                              style: TextStyle(color: textColor, height: 1.5),
                            )
                          else
                            Text(context.tr('No text provided.'), style: TextStyle(color: subtitleColor, fontStyle: FontStyle.italic)),
                          
                          if (submission['attachment_url'] != null && submission['attachment_url'].toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () {
                                // Launch URL placeholder
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.attachment, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      submission['attachment_url'],
                                      style: const TextStyle(color: AppColors.primary, decoration: TextDecoration.underline),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (answers.isNotEmpty) ...[
                    Text(context.tr('Student Answers:'), style: AppTypography.titleMedium(textColor).copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: answers.length,
                        itemBuilder: (ctx, idx) {
                          final ans = answers[idx];
                          final q = ans['questions'] ?? {};
                          final opt = ans['question_options'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Q: ${q['prompt'] ?? 'Unknown'}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('A: ${opt != null ? opt['text'] : (ans['text_answer'] ?? 'No Answer')}', style: TextStyle(color: textColor)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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
                            final isExam = submission['assessment_type'] == 'exam';
                            final rpcName = isExam ? 'grade_exam_attempt_with_feedback' : 'grade_homework_submission';
                            final paramIdName = isExam ? 'p_attempt_id' : 'p_submission_id';
                            
                            await Supabase.instance.client.rpc(
                              rpcName,
                              params: {
                                paramIdName: submission['id'],
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
                        if (_resetRequests.isNotEmpty) ...[
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                context.tr('Pending Reset Requests'),
                                style: AppTypography.titleMedium(textColor).copyWith(fontWeight: FontWeight.bold, color: AppColors.error),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                                  final req = _resetRequests[i];
                                  final studentName = req['students']?['profiles']?['full_name'] ?? 'Student';
                                  final examTitle = req['exams']?['title'] ?? 'Exam';
                                  return Card(
                                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: AppColors.error),
                                    ),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                                      title: Text('$studentName requested a reset for $examTitle', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                      subtitle: Text('${context.tr("Reason")}: ${req["reason"]}', style: TextStyle(color: subtitleColor)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.close, color: Colors.grey),
                                            onPressed: () => _handleResetRequest(req, false),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.check, color: AppColors.success),
                                            onPressed: () => _handleResetRequest(req, true),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                childCount: _resetRequests.length,
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                context.tr('Submissions'),
                                style: AppTypography.titleMedium(textColor).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
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
                                                  '[${(sub['assessment_type'] as String?)?.toUpperCase() ?? 'HOMEWORK'}] ${sub['assessment_title'] ?? context.tr("Assessment")} | ${context.tr('Status')}: ${context.tr((sub['status'] as String? ?? "submitted"))} | ${context.tr('Score')}: ${sub['score'] ?? context.tr("Pending")}',
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
