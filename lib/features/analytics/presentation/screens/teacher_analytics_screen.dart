import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/components/cards.dart';

class TeacherAnalyticsScreen extends StatefulWidget {
  final String profileId;

  const TeacherAnalyticsScreen({super.key, required this.profileId});

  @override
  State<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends State<TeacherAnalyticsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _attempts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final examsRes = await Supabase.instance.client
          .from('exams')
          .select('id, title, max_attempts, pass_score, status')
          .eq('created_by', widget.profileId);

      final examsList = List<Map<String, dynamic>>.from(examsRes);

      if (examsList.isEmpty) {
        if (!mounted) return;

        setState(() {
          _exams = [];
          _attempts = [];
          _isLoading = false;
        });
        return;
      }

      final examIds = examsList.map((e) => e['id'] as String).toList();

      final attemptsRes = await Supabase.instance.client
          .from('exam_attempts')
          .select('id, exam_id, status, score, max_score, student_id')
          .inFilter('exam_id', examIds);

      final attemptsList = List<Map<String, dynamic>>.from(attemptsRes);

      if (!mounted) return;

      setState(() {
        _exams = examsList;
        _attempts = attemptsList;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final subtitleColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              context.tr('Failed to load analytics'),
              style: AppTypography.titleLarge(textColor),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: AppTypography.bodyMedium(subtitleColor),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              child: Text(context.tr('Retry')),
            ),
          ],
        ),
      );
    }

    if (_exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: subtitleColor),
            const SizedBox(height: 16),
            Text(
              context.tr('No Analytics Available'),
              style: AppTypography.titleLarge(textColor),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('You have not created any exams yet.'),
              style: AppTypography.bodyMedium(subtitleColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _exams.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildOverviewCard(textColor, subtitleColor);
          }
          final exam = _exams[index - 1];
          return _buildExamCard(exam, textColor, subtitleColor);
        },
      ),
    );
  }

  Widget _buildOverviewCard(Color textColor, Color subtitleColor) {
    int totalAttempts = _attempts.length;
    int gradedAttempts = _attempts
        .where((a) => a['status'] == 'graded' || a['score'] != null)
        .length;
    double avgScore = 0.0;

    if (gradedAttempts > 0) {
      double totalScore = 0.0;
      for (var a in _attempts) {
        if (a['score'] != null) {
          double score = (a['score'] as num).toDouble();
          double maxScore = (a['max_score'] as num?)?.toDouble() ?? 100.0;
          if (maxScore > 0) {
            totalScore += (score / maxScore) * 100;
          }
        }
      }
      avgScore = totalScore / gradedAttempts;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: CustomCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.insights,
                  color: AppColors.teacherRole,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('Overall Performance'),
                  style: AppTypography.titleLarge(textColor),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  context.tr('Total Exams'),
                  _exams.length.toString(),
                  textColor,
                  subtitleColor,
                ),
                _buildStatColumn(
                  context.tr('Attempts'),
                  totalAttempts.toString(),
                  textColor,
                  subtitleColor,
                ),
                _buildStatColumn(
                  context.tr('Avg Score'),
                  '${avgScore.toStringAsFixed(1)}%',
                  textColor,
                  subtitleColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    String label,
    String value,
    Color textColor,
    Color subtitleColor,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.displaySmall(
            textColor,
          ).copyWith(color: AppColors.teacherRole, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.bodyMedium(subtitleColor)),
      ],
    );
  }

  Widget _buildExamCard(
    Map<String, dynamic> exam,
    Color textColor,
    Color subtitleColor,
  ) {
    final examId = exam['id'];
    final title = exam['title'] ?? 'Untitled Exam';

    final examAttempts = _attempts
        .where((a) => a['exam_id'] == examId)
        .toList();
    final gradedAttempts = examAttempts
        .where((a) => a['status'] == 'graded' || a['score'] != null)
        .toList();

    double avgScore = 0.0;
    if (gradedAttempts.isNotEmpty) {
      double totalScore = 0.0;
      for (var a in gradedAttempts) {
        double score = (a['score'] as num).toDouble();
        double maxScore = (a['max_score'] as num?)?.toDouble() ?? 100.0;
        if (maxScore > 0) {
          totalScore += (score / maxScore) * 100;
        }
      }
      avgScore = totalScore / gradedAttempts.length;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: CustomCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleMedium(textColor)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Attempts'),
                      style: AppTypography.caption(subtitleColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${examAttempts.length}',
                      style: AppTypography.bodyLarge(textColor),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Graded'),
                      style: AppTypography.caption(subtitleColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${gradedAttempts.length}',
                      style: AppTypography.bodyLarge(textColor),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Avg Score'),
                      style: AppTypography.caption(subtitleColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gradedAttempts.isEmpty
                          ? '-'
                          : '${avgScore.toStringAsFixed(1)}%',
                      style: AppTypography.bodyLarge(textColor).copyWith(
                        color: gradedAttempts.isEmpty
                            ? null
                            : _getScoreColor(avgScore),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }
}
