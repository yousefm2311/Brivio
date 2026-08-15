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

      final lessons = await _safeFetchPublishedLessons(studentId);
      final gamification = await _fetchGamificationSummary();
      final completed = lessons
          .where((lesson) => lesson.progressPercentage >= 100)
          .length;
      final trackedSeconds = lessons.fold<int>(
        0,
        (sum, lesson) => sum + lesson.timeSpentSeconds,
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
            value: _formatDuration(trackedSeconds),
            helper: 'Tracked',
          ),
          StudyMetric(
            label: 'XP',
            value: gamification.totalXp.toString(),
            helper: 'Level ${gamification.level}',
          ),
          StudyMetric(
            label: 'Streak',
            value: '${gamification.streakDays}d',
            helper: 'Learning days',
          ),
        ],
        enrolledGroupCount: groups.length,
        gamification: gamification,
      );
    } catch (_) {
      return const StudentLearningSnapshot(
        availableLessons: [],
        metrics: [
          StudyMetric(label: 'Groups', value: '0', helper: 'Unavailable'),
          StudyMetric(label: 'Lessons', value: '0', helper: 'Unavailable'),
          StudyMetric(label: 'Completed', value: '0', helper: 'Lessons'),
          StudyMetric(label: 'Study time', value: '0m', helper: 'Tracked'),
        ],
        enrolledGroupCount: 0,
      );
    }
  }

  Future<List<StudyLessonSummary>> _safeFetchPublishedLessons(
    String studentId,
  ) async {
    try {
      return await _fetchPublishedLessons(studentId);
    } catch (_) {
      return [];
    }
  }

  Future<StudentGamificationSummary> _fetchGamificationSummary() async {
    try {
      final response = await _wrapper.client.rpc(
        'get_current_student_gamification_summary',
      );
      return StudentGamificationSummary.fromJson(response as Map);
    } catch (_) {
      return StudentGamificationSummary.empty;
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

  Future<List<StudyLessonSummary>> _fetchPublishedLessons(
    String studentId,
  ) async {
    final lessonsResponse = await _fetchAccessibleLessons(studentId);
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
          groupId: lesson['group_id'] as String?,
          progressPercentage: progressPercentage.clamp(0, 100),
          estimatedMinutes: (lesson['estimated_minutes'] as num?)?.round() ?? 0,
          lastPage: lastPage.clamp(1, totalPages),
          totalPages: totalPages,
          timeSpentSeconds:
              (lesson['time_spent_seconds'] as num?)?.round() ?? 0,
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

  Future<dynamic> _fetchAccessibleLessons(String studentId) async {
    return _wrapper.client.rpc(
      'get_accessible_student_lessons',
      params: {'p_student_id': studentId},
    );
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

  String _formatDuration(int seconds) {
    return _formatMinutes(seconds ~/ 60);
  }
}
