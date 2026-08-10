import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/components/buttons.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../domain/models/assessment_models.dart';

class QuestionBankWidget extends StatelessWidget {
  final List<Question> questions;
  final bool isLoading;

  const QuestionBankWidget({
    super.key,
    required this.questions,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.tr('No questions found in Question Bank.')),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final q = questions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.shade100,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            title: Text(
              q.prompt,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${context.tr('Type')}: ${context.tr(q.questionType.name)} | ${context.tr('Points')}: ${q.defaultPoints} | ${context.tr('Difficulty')}: ${context.tr(q.difficulty)}',
            ),
            trailing: Chip(
              label: Text('${q.options.length} ${context.tr('options')}'),
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        );
      },
    );
  }
}

class HomeworkListWidget extends StatelessWidget {
  final List<Homework> homeworkList;
  final bool isLoading;

  const HomeworkListWidget({
    super.key,
    required this.homeworkList,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (homeworkList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.tr('No assigned homework found.')),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: homeworkList.length,
      itemBuilder: (context, index) {
        final hw = homeworkList[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.assignment, color: Colors.blue, size: 36),
            title: Text(
              hw.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${context.tr('Due')}: ${hw.dueAt.toLocal().toString().split(' ')[0]} | ${context.tr('Max Score')}: ${hw.maxScore}',
            ),
            trailing: Chip(
              label: Text(context.l10n.t(hw.status).toUpperCase()),
              backgroundColor: Colors.blue.shade100,
            ),
          ),
        );
      },
    );
  }
}

class ExamListWidget extends StatelessWidget {
  final List<Exam> exams;
  final bool isLoading;
  final ValueChanged<Exam>? onStartExam;

  const ExamListWidget({
    super.key,
    required this.exams,
    this.isLoading = false,
    this.onStartExam,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (exams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.tr('No available exams found.')),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
        return Card(
          child: ListTile(
            leading: const Icon(
              Icons.timer,
              color: Colors.deepPurple,
              size: 36,
            ),
            title: Text(
              exam.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${context.tr('Duration')}: ${exam.durationMinutes} ${context.tr('min')} | ${context.tr('Questions')}: ${exam.questions.length}',
            ),
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text(context.tr('Start')),
              onPressed: onStartExam != null ? () => onStartExam!(exam) : null,
            ),
          ),
        );
      },
    );
  }
}

class ExamRunnerScreen extends StatefulWidget {
  final Exam exam;
  final ExamAttempt attempt;
  final Function(String questionId, String optionId)? onOptionSelected;
  final VoidCallback? onSubmit;

  const ExamRunnerScreen({
    super.key,
    required this.exam,
    required this.attempt,
    this.onOptionSelected,
    this.onSubmit,
  });

  @override
  State<ExamRunnerScreen> createState() => _ExamRunnerScreenState();
}

class _ExamRunnerScreenState extends State<ExamRunnerScreen> {
  final Map<String, String> _answers = {};
  int _currentQuestionIndex = 0;

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final questions = exam.questions;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(backgroundColor: surfaceColor, title: Text(exam.title, style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800))),
        body: Center(
          child: Text(context.tr('No questions configured for this exam.'), style: AppTypography.bodyLarge(textSecondary)),
        ),
      );
    }

    final currentQuestion = questions[_currentQuestionIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.tr('Exit Exam?')),
            content: Text(context.tr('Are you sure you want to exit? You will not be able to re-enter this exam, and your current answers will be submitted to the teacher.')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(ctx, true), 
                child: Text(context.tr('Exit & Submit'))
              ),
            ],
          ),
        );
        
        if (shouldExit == true) {
          if (widget.onSubmit != null) {
            widget.onSubmit!();
          } else if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        title: Text(exam.title, style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.errorSubtle,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: AppColors.error, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${exam.durationMinutes}:00',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.error, height: 1.2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FadeInSlide(
          key: ValueKey(_currentQuestionIndex),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${context.tr('Question')} ${_currentQuestionIndex + 1} ${context.tr('of')} ${questions.length}',
                      style: AppTypography.bodyMedium(textSecondary).copyWith(fontWeight: FontWeight.w700),
                    ),
                    StatusChip(
                      label: context.tr('Autosaved'),
                      status: ChipStatus.success,
                      icon: Icons.cloud_done_rounded,
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / questions.length,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 32),
                Text(
                  currentQuestion.prompt,
                  style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.w800, height: 1.4),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView.separated(
                    itemCount: currentQuestion.options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final opt = currentQuestion.options[i];
                      final isSelected = _answers[currentQuestion.id] == opt.id;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() => _answers[currentQuestion.id] = opt.id);
                          if (widget.onOptionSelected != null) {
                            widget.onOptionSelected!(currentQuestion.id, opt.id);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primarySubtle : (isDark ? AppColors.darkCard : AppColors.lightCard),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder), width: 2),
                                  color: isSelected ? AppColors.primary : Colors.transparent,
                                ),
                                child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  opt.text,
                                  style: AppTypography.bodyLarge(isSelected ? (isDark ? Colors.white : AppColors.primary) : textPrimary).copyWith(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_currentQuestionIndex > 0)
                      Expanded(
                        child: GhostButton(
                          text: context.tr('Previous'),
                          icon: Icons.arrow_back_rounded,
                          onPressed: () => setState(() => _currentQuestionIndex--),
                        ),
                      )
                    else
                      const Spacer(),
                    
                    const SizedBox(width: 16),
                    
                    Expanded(
                      child: _currentQuestionIndex < questions.length - 1
                          ? PrimaryButton(
                              text: context.tr('Next'),
                              icon: Icons.arrow_forward_rounded,
                              onPressed: () => setState(() => _currentQuestionIndex++),
                            )
                          : PrimaryButton(
                              text: context.tr('Submit Exam'),
                              icon: Icons.check_circle_rounded,
                              color: AppColors.success,
                              onPressed: widget.onSubmit,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}
