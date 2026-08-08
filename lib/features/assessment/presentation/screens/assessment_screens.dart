import 'package:flutter/material.dart';
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No questions found in Question Bank.'),
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
              'Type: ${q.questionType.name.toUpperCase()} | Points: ${q.defaultPoints} | Difficulty: ${q.difficulty}',
            ),
            trailing: Chip(
              label: Text('${q.options.length} options'),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No assigned homework found.'),
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
              'Due: ${hw.dueAt.toLocal().toString().split(' ')[0]} | Max Score: ${hw.maxScore}',
            ),
            trailing: Chip(
              label: Text(hw.status.toUpperCase()),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No available exams found.'),
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
              'Duration: ${exam.durationMinutes} min | Questions: ${exam.questions.length}',
            ),
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
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

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(exam.title)),
        body: const Center(
          child: Text('No questions configured for this exam.'),
        ),
      );
    }

    final currentQuestion = questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(exam.title),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Row(
                children: [
                  const Icon(Icons.alarm, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    '${exam.durationMinutes}:00',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Chip(
                  avatar: Icon(Icons.cloud_done, size: 16, color: Colors.green),
                  label: Text('Autosaved'),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              currentQuestion.prompt,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  for (final opt in currentQuestion.options)
                    // ignore: deprecated_member_use
                    RadioListTile<String>(
                      title: Text(opt.text),
                      value: opt.id,
                      // ignore: deprecated_member_use
                      groupValue: _answers[currentQuestion.id],
                      // ignore: deprecated_member_use
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _answers[currentQuestion.id] = val;
                          });
                          if (widget.onOptionSelected != null) {
                            widget.onOptionSelected!(currentQuestion.id, val);
                          }
                        }
                      },
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _currentQuestionIndex > 0
                      ? () => setState(() => _currentQuestionIndex--)
                      : null,
                  child: const Text('Previous'),
                ),
                if (_currentQuestionIndex < questions.length - 1)
                  ElevatedButton(
                    onPressed: () => setState(() => _currentQuestionIndex++),
                    child: const Text('Next'),
                  )
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Submit Exam'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: widget.onSubmit,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
