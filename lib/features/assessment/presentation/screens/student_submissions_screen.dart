import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class StudentSubmissionsScreen extends StatefulWidget {
  final Map<String, dynamic> initialSubmission;
  final VoidCallback onGraded;

  const StudentSubmissionsScreen({
    super.key,
    required this.initialSubmission,
    required this.onGraded,
  });

  @override
  State<StudentSubmissionsScreen> createState() => _StudentSubmissionsScreenState();
}

class _StudentSubmissionsScreenState extends State<StudentSubmissionsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allAttempts = [];
  Map<String, List<Map<String, dynamic>>> _answersByAttempt = {};
  
  late TextEditingController _scoreCtrl;
  late TextEditingController _feedbackCtrl;

  @override
  void initState() {
    super.initState();
    _scoreCtrl = TextEditingController(text: widget.initialSubmission['score']?.toString() ?? '95');
    _feedbackCtrl = TextEditingController(text: 'Excellent solution!');
    _fetchAllAttemptsAndAnswers();
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAllAttemptsAndAnswers() async {
    try {
      final isExam = widget.initialSubmission['assessment_type'] == 'exam';
      final table = isExam ? 'exam_attempts' : 'homework_submissions';
      final foreignKeyAssess = isExam ? 'exam_id' : 'homework_id';
      
      final assessmentId = widget.initialSubmission['assessment_id'];
      final studentId = widget.initialSubmission['student_id'];

      // Fetch all attempts for this student and assessment
      final attemptsRes = await Supabase.instance.client
          .from(table)
          .select('*')
          .eq(foreignKeyAssess, assessmentId)
          .eq('student_id', studentId)
          .order('created_at', ascending: true);
          
      final attemptsList = List<Map<String, dynamic>>.from(attemptsRes);
      
      // Fetch answers for all these attempts
      final ansTable = isExam ? 'attempt_answers' : 'homework_answers';
      final ansForeignKey = isExam ? 'attempt_id' : 'submission_id';
      
      final attemptIds = attemptsList.map((a) => a['id']).toList();
      
      if (attemptIds.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
      
      // We also need question options for the questions to see correct answers
      // We will join questions and question_options
      final answersRes = await Supabase.instance.client
          .from(ansTable)
          .select('*, questions(*, question_options(*)), question_options(*)')
          .inFilter(ansForeignKey, attemptIds);
          
      final allAnswers = List<Map<String, dynamic>>.from(answersRes);
      
      final Map<String, List<Map<String, dynamic>>> groupedAnswers = {};
      for (var ans in allAnswers) {
        final aId = ans[ansForeignKey].toString();
        groupedAnswers[aId] = groupedAnswers[aId] ?? [];
        groupedAnswers[aId]!.add(ans);
      }

      if (mounted) {
        setState(() {
          _allAttempts = attemptsList;
          _answersByAttempt = groupedAnswers;
          
          // Update score field based on the most recent attempt if not manually edited
          if (_allAttempts.isNotEmpty) {
             _scoreCtrl.text = _allAttempts.last['score']?.toString() ?? '0';
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch multiple attempts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _manualOverrideGrade(String attemptId, String questionId, bool currentCorrect, num currentPoints) {
    bool isCorrect = currentCorrect;
    TextEditingController pointsCtrl = TextEditingController(text: currentPoints.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text(context.tr('Manual Grade Override')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text(context.tr('Is Correct?')),
                    value: isCorrect,
                    onChanged: (val) {
                      setDialogState(() {
                        isCorrect = val;
                      });
                    },
                  ),
                  TextField(
                    controller: pointsCtrl,
                    decoration: InputDecoration(labelText: context.tr('Points Awarded')),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    
                    try {
                      final newPoints = double.tryParse(pointsCtrl.text) ?? 0.0;
                      final res = await Supabase.instance.client.rpc(
                        'manual_grade_override',
                        params: {
                          'p_attempt_id': attemptId,
                          'p_question_id': questionId,
                          'p_is_correct': isCorrect,
                          'p_points': newPoints,
                        },
                      );
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(context.tr('Override applied successfully! New Score: ') + res['new_score'].toString()),
                          backgroundColor: Colors.green,
                        ));
                        
                        setState(() {
                          _isLoading = true;
                        });
                        await _fetchAllAttemptsAndAnswers();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(context.tr('Failed to override grade: ') + e.toString()),
                          backgroundColor: Colors.red,
                        ));
                      }
                    }
                  },
                  child: Text(context.tr('Save Override')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAnswersList(List<Map<String, dynamic>> answers, Color textColor, String attemptId) {
    if (answers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(context.tr('No answers provided.'), style: TextStyle(color: textColor, fontStyle: FontStyle.italic)),
      );
    }
    
    final isExam = widget.initialSubmission['assessment_type'] == 'exam';

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: answers.length,
      itemBuilder: (ctx, idx) {
        final ans = answers[idx];
        final q = ans['questions'] ?? {};
        final opt = ans['question_options'];
        
        final allOptions = q['question_options'] as List<dynamic>? ?? [];
        final correctOption = allOptions.cast<Map<String,dynamic>>().firstWhere((o) => o['is_correct'] == true, orElse: () => {});
        
        final isCorrect = ans['is_correct'] ?? false;
        final pointsAwarded = ans['points_awarded'] ?? 0;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isCorrect ? Colors.green : Colors.red, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Q: ${q['prompt'] ?? 'Unknown'}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  ),
                  if (isExam)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text(context.tr('Override')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        _manualOverrideGrade(attemptId, q['id'], isCorrect, pointsAwarded);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${context.tr('Student Answer')}: ${opt != null ? opt['text'] : (ans['text_answer'] ?? 'No Answer')}', style: TextStyle(color: textColor)),
              const SizedBox(height: 4),
              Text('${context.tr('Correct Answer')}: ${correctOption['text'] ?? 'N/A'}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${context.tr('Points')}: $pointsAwarded', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ],
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

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Student Submissions')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Manual Grading & Feedback'),
                      style: AppTypography.displaySmall(textColor),
                    ),
                    const SizedBox(height: 16),
                    
                    if (_allAttempts.length > 1) ...[
                      Text(context.tr('Student Attempts History'), style: AppTypography.titleMedium(textColor).copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DefaultTabController(
                        length: _allAttempts.length,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TabBar(
                              isScrollable: true,
                              labelColor: AppColors.primary,
                              unselectedLabelColor: subtitleColor,
                              tabs: List.generate(_allAttempts.length, (idx) {
                                final attemptNum = _allAttempts[idx]['attempt_number'] ?? (idx + 1);
                                return Tab(text: '${context.tr("Attempt")} $attemptNum');
                              }),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: TabBarView(
                                children: _allAttempts.map((attempt) {
                                  final aId = attempt['id'].toString();
                                  final answers = _answersByAttempt[aId] ?? [];
                                  return SingleChildScrollView(
                                    child: _buildAnswersList(answers, textColor, aId),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_allAttempts.isNotEmpty) ...[
                      Text(context.tr('Student Answers:'), style: AppTypography.titleMedium(textColor).copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildAnswersList(_answersByAttempt[_allAttempts.first['id'].toString()] ?? [], textColor, _allAttempts.first['id'].toString()),
                    ],
                    
                    const SizedBox(height: 24),
                    TextField(
                      controller: _scoreCtrl,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: context.tr('Final Score'),
                        helperText: context.tr('Auto-calculated but can be manually changed.'),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _feedbackCtrl,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(labelText: context.tr('Teacher Feedback')),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.tr('Cancel'), style: TextStyle(color: textColor)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: () async {
                            final nav = Navigator.of(context);
                            final score = double.tryParse(_scoreCtrl.text) ?? 90.0;
                            try {
                              final isExam = widget.initialSubmission['assessment_type'] == 'exam';
                              final rpcName = isExam ? 'grade_exam_attempt_with_feedback' : 'grade_homework_submission';
                              final paramIdName = isExam ? 'p_attempt_id' : 'p_submission_id';
                              
                              await Supabase.instance.client.rpc(
                                rpcName,
                                params: {
                                  paramIdName: widget.initialSubmission['id'],
                                  'p_score': score,
                                  'p_feedback': _feedbackCtrl.text.trim().isEmpty ? null : _feedbackCtrl.text.trim(),
                                },
                              );

                              nav.pop();
                              widget.onGraded();
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
                          child: Text(context.tr('Submit Final Grade')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
