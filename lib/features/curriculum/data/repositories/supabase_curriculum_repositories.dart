import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../../core/errors/failures.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/curriculum_models.dart';
import '../../domain/repositories/curriculum_repositories.dart';

class SupabaseSemesterRepository implements ISemesterRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseSemesterRepository(this._wrapper);

  @override
  Future<List<Semester>> fetchSemestersForSubject(String subjectId) async {
    try {
      final response = await _wrapper.client
          .from('semesters')
          .select()
          .eq('subject_id', subjectId)
          .order('order_number');
      return (response as List)
          .map((j) => Semester.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch semesters: ${e.toString()}',
      );
    }
  }

  @override
  Future<Semester> createSemester(Semester semester) async {
    try {
      final response = await _wrapper.client.rpc(
        'create_semester_runtime',
        params: {
          'p_subject_id': semester.subjectId,
          'p_name': semester.name,
          'p_code': semester.code,
          'p_order_number': semester.orderNumber,
          'p_start_date': semester.startDate
              ?.toIso8601String()
              .split('T')
              .first,
          'p_end_date': semester.endDate?.toIso8601String().split('T').first,
          'p_status': semester.status,
        },
      );
      return Semester.fromJson(Map<String, dynamic>.from(response as Map));
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: 'Failed to create semester: ${e.message}');
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to create semester: ${e.toString()}',
      );
    }
  }
}

class SupabaseUnitRepository implements IUnitRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseUnitRepository(this._wrapper);

  @override
  Future<List<Unit>> fetchUnitsForSemester(String semesterId) async {
    try {
      final response = await _wrapper.client
          .from('units')
          .select()
          .eq('semester_id', semesterId)
          .order('order_number');
      return (response as List)
          .map((j) => Unit.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(message: 'Failed to fetch units: ${e.toString()}');
    }
  }

  @override
  Future<Unit> createUnit(Unit unit) async {
    try {
      final response = await _wrapper.client
          .from('units')
          .insert({
            'semester_id': unit.semesterId,
            'name': unit.name,
            'code': unit.code,
            'order_number': unit.orderNumber,
            'status': unit.status,
          })
          .select()
          .single();
      return Unit.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(message: 'Failed to create unit: ${e.toString()}');
    }
  }
}

class SupabaseLessonRepository implements ILessonRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseLessonRepository(this._wrapper);

  @override
  Future<List<Lesson>> fetchLessonsForUnit(String unitId) async {
    try {
      final response = await _wrapper.client
          .from('lessons')
          .select('*, lesson_resources(*)')
          .eq('unit_id', unitId)
          .order('order_number');

      return (response as List).map((j) {
        final Map<String, dynamic> item = Map<String, dynamic>.from(j as Map);
        final rawRes = item['lesson_resources'] as List<dynamic>? ?? [];
        final res = rawRes
            .map(
              (r) =>
                  LessonResource.fromJson(Map<String, dynamic>.from(r as Map)),
            )
            .toList();
        return Lesson.fromJson(item, res);
      }).toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch lessons: ${e.toString()}',
      );
    }
  }

  @override
  Future<Lesson> getLessonById(String lessonId) async {
    try {
      final response = await _wrapper.client
          .from('lessons')
          .select('*, lesson_resources(*)')
          .eq('id', lessonId)
          .single();

      final rawRes = response['lesson_resources'] as List<dynamic>? ?? [];
      final res = rawRes
          .map(
            (r) => LessonResource.fromJson(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
      return Lesson.fromJson(response, res);
    } catch (e) {
      throw DatabaseFailure(message: 'Lesson not found: ${e.toString()}');
    }
  }

  @override
  Future<Lesson> createLesson(Lesson lesson) async {
    try {
      final response = await _wrapper.client
          .from('lessons')
          .insert({
            'unit_id': lesson.unitId,
            'title': lesson.title,
            'lesson_type': lesson.lessonType.toDbValue(),
            'order_number': lesson.orderNumber,
            'status': lesson.status.toDbValue(),
            'estimated_duration_minutes': lesson.estimatedDurationMinutes,
          })
          .select()
          .single();
      return Lesson.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to create lesson: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> publishLesson(String lessonId, {bool publish = true}) async {
    try {
      await _wrapper.client.from('lessons').update({
        'status': publish ? 'published' : 'draft',
        'published_at': publish ? DateTime.now().toUtc().toIso8601String() : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', lessonId);
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Publish operation failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> reorderLessons({
    required String unitId,
    required List<String> orderedLessonIds,
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'reorder_lessons',
        params: {'p_unit_id': unitId, 'p_ordered_lesson_ids': orderedLessonIds},
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(message: 'Lesson reordering failed');
      }
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Lesson reordering failed: ${e.toString()}',
      );
    }
  }
}

class SupabaseLessonResourceRepository implements ILessonResourceRepository {
  final SupabaseClientWrapper _wrapper;
  static const int signedUrlTtlSeconds = 900; // Central TTL = 15 Minutes

  SupabaseLessonResourceRepository(this._wrapper);

  @override
  Future<List<LessonResource>> fetchResourcesForLesson(String lessonId) async {
    try {
      final response = await _wrapper.client
          .from('lesson_resources')
          .select()
          .eq('lesson_id', lessonId)
          .order('order_number');
      return (response as List)
          .map((j) => LessonResource.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch resources: ${e.toString()}',
      );
    }
  }

  @override
  Future<LessonResource> createResource(LessonResource resource) async {
    try {
      final response = await _wrapper.client
          .from('lesson_resources')
          .insert({
            'lesson_id': resource.lessonId,
            'title': resource.title,
            'resource_type': resource.resourceType,
            'bucket': resource.bucket,
            'object_path': resource.objectPath,
            'order_number': resource.orderNumber,
          })
          .select()
          .single();
      return LessonResource.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to create resource: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> deleteResource(String resourceId) async {
    try {
      await _wrapper.client
          .from('lesson_resources')
          .delete()
          .eq('id', resourceId);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to delete resource: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> reorderResources({
    required String lessonId,
    required List<String> orderedResourceIds,
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'reorder_lesson_resources',
        params: {'p_lesson_id': lessonId, 'p_ordered_ids': orderedResourceIds},
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(message: 'Resource reordering failed');
      }
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Resource reordering failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<String> getAuthorizedAssetUrl(String resourceId) async {
    try {
      final res = await _wrapper.client
          .from('lesson_resources')
          .select('bucket, object_path, lesson_id')
          .eq('id', resourceId)
          .single();

      final lessonId = res['lesson_id'] as String;
      final bucket = res['bucket'] as String;
      final path = res['object_path'] as String;

      // Server-authoritative check: Verify caller access to target lesson
      final bool canAccess = await _wrapper.client.rpc(
        'current_student_can_access_lesson',
        params: {'p_lesson_id': lessonId},
      );

      if (!canAccess) {
        throw PermissionFailure(
          message: 'Access denied for requested lesson resource',
        );
      }

      // Generate signed URL with central TTL
      final url = await _wrapper.client.storage
          .from(bucket)
          .createSignedUrl(path, signedUrlTtlSeconds);
      return url;
    } on Failure {
      rethrow;
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to generate authorized asset URL: ${e.toString()}',
      );
    }
  }
}

class SupabaseLessonProgressRepository implements ILessonProgressRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseLessonProgressRepository(this._wrapper);

  @override
  Future<LessonProgress?> fetchProgressForLesson(String lessonId) async {
    try {
      final user = _wrapper.client.auth.currentUser;
      if (user == null) return null;

      final studentRes = await _wrapper.client
          .from('students')
          .select('id')
          .eq('profile_id', user.id)
          .maybeSingle();

      if (studentRes == null) return null;
      final studentId = studentRes['id'] as String;

      final response = await _wrapper.client
          .from('lesson_progress')
          .select()
          .eq('student_id', studentId)
          .eq('lesson_id', lessonId)
          .maybeSingle();

      if (response == null) return null;
      return LessonProgress.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch lesson progress: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> updateProgress({
    required String lessonId,
    required String status,
    int progressPercentage = 0,
    int lastPositionSeconds = 0,
    int timeSpentSeconds = 0,
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'update_lesson_progress',
        params: {
          'p_lesson_id': lessonId,
          'p_status': status,
          'p_progress_percentage': progressPercentage,
          'p_last_position_seconds': lastPositionSeconds,
          'p_time_spent_seconds': timeSpentSeconds,
        },
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(message: 'Progress update failed');
      }
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(message: 'Progress update failed: ${e.toString()}');
    }
  }
}
