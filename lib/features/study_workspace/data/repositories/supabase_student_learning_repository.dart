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

      final subjectIds = groups
          .map((group) => group['subject_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      final lessons = await _fetchPublishedLessons(subjectIds, studentId);
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
    final response = await _wrapper.client
        .from('enrollments')
        .select('groups(id, name, code, subject_id, status)')
        .eq('student_id', studentId)
        .eq('status', 'active');

    return (response as List)
        .map((row) => row as Map<String, dynamic>)
        .map((row) => row['groups'])
        .whereType<Map>()
        .map((group) => Map<String, dynamic>.from(group))
        .where((group) => group['status'] == 'active')
        .toList();
  }

  Future<List<StudyLessonSummary>> _fetchPublishedLessons(
    List<String> subjectIds,
    String studentId,
  ) async {
    if (subjectIds.isEmpty) return [];

    final semestersResponse = await _wrapper.client
        .from('semesters')
        .select('id, subject_id')
        .inFilter('subject_id', subjectIds)
        .eq('status', 'active');
    final semesters = (semestersResponse as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final semesterIds = semesters.map((sem) => sem['id'] as String).toList();
    if (semesterIds.isEmpty) return [];
    final subjectIdBySemesterId = {
      for (final sem in semesters)
        sem['id'] as String: sem['subject_id'] as String,
    };

    final unitsResponse = await _wrapper.client
        .from('units')
        .select('id, name, semester_id, order_number')
        .inFilter('semester_id', semesterIds)
        .eq('status', 'active')
        .order('order_number');
    final units = (unitsResponse as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final unitIds = units.map((unit) => unit['id'] as String).toList();
    if (unitIds.isEmpty) return [];
    final subjectResponse = await _wrapper.client
        .from('subjects')
        .select('id, name')
        .inFilter('id', subjectIds);
    final subjectById = {
      for (final row in subjectResponse as List)
        (row as Map)['id'] as String: row['name'] as String? ?? 'Subject',
    };

    final lessonsResponse = await _wrapper.client
        .from('lessons')
        .select('*, lesson_resources(*)')
        .inFilter('unit_id', unitIds)
        .eq('status', 'published')
        .order('order_number');
    final rawLessons = (lessonsResponse as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    if (rawLessons.isEmpty) return [];

    final lessonIds = rawLessons
        .map((lesson) => lesson['id'] as String)
        .toList();
    final progressResponse = await _wrapper.client
        .from('lesson_progress')
        .select()
        .eq('student_id', studentId)
        .inFilter('lesson_id', lessonIds);
    final progressByLesson = {
      for (final row in progressResponse as List)
        (row as Map)['lesson_id'] as String: Map<String, dynamic>.from(row),
    };

    final unitById = {for (final unit in units) unit['id'] as String: unit};
    final summaries = <StudyLessonSummary>[];

    for (final lesson in rawLessons) {
      final unit = unitById[lesson['unit_id']];
      final unitSubjectId =
          subjectIdBySemesterId[unit?['semester_id'] as String?];
      final resources = (lesson['lesson_resources'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((resource) => Map<String, dynamic>.from(resource))
          .toList();
      final pdfResource = resources.cast<Map<String, dynamic>?>().firstWhere(
        (resource) => resource?['resource_type'] == 'pdf',
        orElse: () => null,
      );
      final progress = progressByLesson[lesson['id']];
      final progressPercentage =
          (progress?['progress_percentage'] as num?)?.round() ?? 0;
      final lastPosition = progress?['last_position']?.toString();
      final lastPage = int.tryParse(lastPosition ?? '') ?? 1;
      final totalPages =
          int.tryParse(
            (pdfResource?['metadata'] as Map?)?['page_count']?.toString() ?? '',
          ) ??
          1;

      summaries.add(
        StudyLessonSummary(
          id: lesson['id'] as String,
          title: lesson['title'] as String? ?? 'Untitled lesson',
          pathName: subjectById[unitSubjectId] ?? 'Assigned subject',
          unitName: unit?['name'] as String? ?? 'Unit',
          progressPercentage: progressPercentage.clamp(0, 100),
          estimatedMinutes: lesson['estimated_duration_minutes'] as int? ?? 0,
          lastPage: lastPage.clamp(1, totalPages),
          totalPages: totalPages,
          xp: progressPercentage >= 100 ? 100 : 0,
          hasPdf: pdfResource != null,
          hasCodePlayground: lesson['lesson_type'] == 'programming',
          pdfUrl: pdfResource == null
              ? null
              : await _createSignedUrl(pdfResource),
        ),
      );
    }

    return summaries;
  }

  Future<String> _createSignedUrl(Map<String, dynamic> resource) {
    return _wrapper.client.storage
        .from(resource['bucket'] as String)
        .createSignedUrl(resource['object_path'] as String, 900);
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '${hours}h';
    return '${hours}h ${rest}m';
  }
}
