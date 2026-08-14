import 'package:flutter/material.dart';
import '../../domain/models/curriculum_models.dart';

class CurriculumHierarchyWidget extends StatelessWidget {
  final List<Semester> semesters;
  final List<Unit> units;
  final List<Lesson> lessons;
  final bool isLoading;
  final ValueChanged<Lesson>? onLessonSelected;

  const CurriculumHierarchyWidget({
    super.key,
    required this.semesters,
    required this.units,
    required this.lessons,
    this.isLoading = false,
    this.onLessonSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (semesters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No curriculum semesters found.'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        for (final sem in semesters) ...[
          Card(
            color: Colors.blue.shade50,
            child: ListTile(
              leading: const Icon(Icons.school, color: Colors.blue),
              title: Text(
                '${sem.name} (${sem.code})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Status: ${sem.status}'),
            ),
          ),
          const SizedBox(height: 8),
          for (final u in units.where((u) => u.semesterId == sem.id)) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: const Icon(Icons.folder, color: Colors.amber),
                title: Text(
                  '${u.name} (${u.code})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                children: [
                  for (final l in lessons.where((l) => l.unitId == u.id))
                    ListTile(
                      enabled: l.status == LessonStatus.published,
                      onTap:
                          l.status == LessonStatus.published &&
                              onLessonSelected != null
                          ? () => onLessonSelected!(l)
                          : null,
                      leading: Icon(
                        l.lessonType == LessonType.video
                            ? Icons.play_circle
                            : l.lessonType == LessonType.pdf
                            ? Icons.picture_as_pdf
                            : Icons.article,
                        color: l.status == LessonStatus.published
                            ? Colors.deepPurple
                            : Colors.grey,
                      ),
                      title: Text(
                        l.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(l.lessonType.name.toUpperCase()),
                          Text(
                            'Duration: ${l.estimatedDurationMinutes ?? 10} min',
                          ),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            label: Text(l.status.name),
                            backgroundColor: l.status == LessonStatus.published
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class LessonPlayerScreen extends StatefulWidget {
  final Lesson lesson;
  final LessonProgress? progress;
  final ValueChanged<int>? onProgressUpdate;

  const LessonPlayerScreen({
    super.key,
    required this.lesson,
    this.progress,
    this.onProgressUpdate,
  });

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  bool _isPlaying = false;
  double _currentPositionSeconds = 0;
  int _pdfCurrentPage = 1;
  final int _pdfTotalPages = 12;

  @override
  void initState() {
    super.initState();
    if (widget.progress != null) {
      _currentPositionSeconds = widget.progress!.lastPositionSeconds.toDouble();
      if (widget.lesson.lessonType == LessonType.pdf) {
        _pdfCurrentPage = widget.progress!.lastPositionSeconds > 0
            ? widget.progress!.lastPositionSeconds
            : 1;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final progress = widget.progress;

    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  lesson.lessonType == LessonType.video
                      ? Icons.play_circle
                      : lesson.lessonType == LessonType.pdf
                      ? Icons.picture_as_pdf
                      : Icons.article,
                  size: 36,
                  color: Colors.deepPurple,
                ),
                title: Text(
                  lesson.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Type: ${lesson.lessonType.name.toUpperCase()} | Status: ${lesson.status.name}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _buildLessonContent(context),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progress: ${progress?.progressPercentage ?? 0}%'),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark Complete'),
                  onPressed: () {
                    if (widget.onProgressUpdate != null) {
                      widget.onProgressUpdate!(100);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonContent(BuildContext context) {
    final lesson = widget.lesson;

    switch (lesson.lessonType) {
      case LessonType.video:
        final totalDuration = (lesson.estimatedDurationMinutes ?? 15) * 60;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library, size: 64, color: Colors.deepPurple),
            const SizedBox(height: 12),
            Text(
              'Video Stream: ${lesson.resources.isNotEmpty ? lesson.resources.first.objectPath : "cs101/intro.mp4"}',
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 48,
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.deepPurple,
                  ),
                  onPressed: () {
                    setState(() => _isPlaying = !_isPlaying);
                  },
                ),
              ],
            ),
            Slider(
              value: _currentPositionSeconds.clamp(
                0.0,
                totalDuration.toDouble(),
              ),
              min: 0.0,
              max: totalDuration.toDouble(),
              onChanged: (val) {
                setState(() => _currentPositionSeconds = val);
              },
            ),
            Text(
              'Position: ${_currentPositionSeconds.toInt()}s / ${totalDuration}s',
            ),
          ],
        );
      case LessonType.pdf:
        final objectPath = lesson.resources.isNotEmpty
            ? lesson.resources.first.objectPath
            : 'cs101/guide.pdf';
        final fileName = objectPath.split('/').last;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 64, color: Colors.red),
            const SizedBox(height: 12),
            Tooltip(
              message: objectPath,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        fileName.isEmpty ? 'lecture.pdf' : fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.navigate_before),
                  onPressed: _pdfCurrentPage > 1
                      ? () => setState(() => _pdfCurrentPage--)
                      : null,
                ),
                Text(
                  'Page $_pdfCurrentPage of $_pdfTotalPages',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.navigate_next),
                  onPressed: _pdfCurrentPage < _pdfTotalPages
                      ? () => setState(() => _pdfCurrentPage++)
                      : null,
                ),
              ],
            ),
          ],
        );
      case LessonType.text:
      default:
        return const SingleChildScrollView(
          child: Text(
            'Welcome to Big O Notation & Algorithm Complexity.\n\n'
            'An algorithm is a step-by-step procedure for solving a problem or accomplishing a task. '
            'Time complexity measures the execution time of an algorithm relative to the input size N.\n\n'
            'Key Complexity Classes:\n'
            '• O(1) Constant Time\n'
            '• O(log N) Logarithmic Time\n'
            '• O(N) Linear Time\n'
            '• O(N log N) Linearithmic Time\n'
            '• O(N^2) Quadratic Time',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        );
    }
  }
}
