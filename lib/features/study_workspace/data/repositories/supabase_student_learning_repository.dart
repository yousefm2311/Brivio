import '../../../../core/errors/failures.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/study_workspace_models.dart';
import '../../domain/repositories/student_learning_repository.dart';

class SupabaseStudentLearningRepository implements IStudentLearningRepository {
  final SupabaseClientWrapper _wrapper;

  SupabaseStudentLearningRepository(this._wrapper);

  @override
  Future<StudentLearningSnapshot> fetchSnapshotForStudent(
    String studentId,
  ) async {
    try {
      final groups = await _fetchStudentGroups(studentId);
      if (groups.isEmpty) {
        return const StudentLearningSnapshot(
          availableLessons: [],
          metrics: [
            StudyMetric(label: 'Groups', value: '0', helper: 'Not enrolled'),
            StudyMetric(label: 'Lessons', value: '0', helper: 'Published'),
            StudyMetric(label: 'Completed', value: '0', helper: 'Lessons'),
            StudyMetric(label: 'Study time', value: '0m', helper: 'Tracked'),
          ],
          enrolledGroupCount: 0,
        );
      }

      final lessons = await _fetchPublishedLessons();
      final completed = lessons
          .where((lesson) => lesson.progressPercentage >= 100)
          .length;
      final totalMinutes = lessons.fold<int>(
        0,
        (sum, lesson) => sum + lesson.estimatedMinutes,
      );

      return StudentLearningSnapshot(
        availableLessons: lessons,
        metrics: [
          StudyMetric(
            label: 'Groups',
            value: groups.length.toString(),
            helper: 'Active enrollments',
          ),
          StudyMetric(
            label: 'Lessons',
            value: lessons.length.toString(),
            helper: 'Published',
          ),
          StudyMetric(
            label: 'Completed',
            value: completed.toString(),
            helper: 'Lessons',
          ),
          StudyMetric(
            label: 'Study time',
            value: _formatMinutes(totalMinutes),
            helper: 'Planned content',
          ),
        ],
        enrolledGroupCount: groups.length,
      );
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to load student learning snapshot: ${e.toString()}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStudentGroups(
    String studentId,
  ) async {
    final response = await _wrapper.client.rpc(
      'get_student_groups',
      params: {'p_student_id': studentId},
    );

    return (response as List)
        .whereType<Map>()
        .map((group) => Map<String, dynamic>.from(group))
        .where((group) => group['status'] == 'active')
        .toList();
  }

  Future<List<StudyLessonSummary>> _fetchPublishedLessons() async {
    final lessonsResponse = await _wrapper.client.rpc(
      'get_current_student_lessons',
    );
    final rawLessons = (lessonsResponse as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    if (rawLessons.isEmpty) return [];

    final summaries = <StudyLessonSummary>[];
    for (final lesson in rawLessons) {
      final progressPercentage =
          (lesson['progress_percentage'] as num?)?.round() ?? 0;
      final totalPages = (lesson['total_pages'] as num?)?.round() ?? 1;
      final lastPage = (lesson['last_page'] as num?)?.round() ?? 1;
      final pdfBucket = lesson['pdf_bucket']?.toString();
      final pdfObjectPath = lesson['pdf_object_path']?.toString();
      summaries.add(
        StudyLessonSummary(
          id: lesson['lesson_id'] as String,
          title: lesson['lesson_title'] as String? ?? 'Untitled lesson',
          pathName: lesson['subject_name'] as String? ?? 'Assigned subject',
          unitName: lesson['unit_name'] as String? ?? 'Unit',
          progressPercentage: progressPercentage.clamp(0, 100),
          estimatedMinutes: (lesson['estimated_minutes'] as num?)?.round() ?? 0,
          lastPage: lastPage.clamp(1, totalPages),
          totalPages: totalPages,
          xp: progressPercentage >= 100 ? 100 : 0,
          hasPdf: pdfBucket != null && pdfObjectPath != null,
          hasCodePlayground: lesson['has_code_playground'] == true,
          pdfUrl: pdfBucket == null || pdfObjectPath == null
              ? null
              : await _createSignedUrl(pdfBucket, pdfObjectPath),
        ),
      );
    }

    return summaries;
  }

  Future<String> _createSignedUrl(String bucket, String objectPath) {
    return _wrapper.client.storage
        .from(bucket)
        .createSignedUrl(objectPath, 900);
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '${hours}h';
    return '${hours}h ${rest}m';
  }
}
