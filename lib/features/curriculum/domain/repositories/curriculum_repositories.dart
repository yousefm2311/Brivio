import '../models/curriculum_models.dart';

abstract class ISemesterRepository {
  Future<List<Semester>> fetchSemestersForSubject(String subjectId);
  Future<Semester> createSemester(Semester semester);
}

abstract class IUnitRepository {
  Future<List<Unit>> fetchUnitsForSemester(String semesterId);
  Future<Unit> createUnit(Unit unit);
}

abstract class ILessonRepository {
  Future<List<Lesson>> fetchLessonsForUnit(String unitId);
  Future<Lesson> getLessonById(String lessonId);
  Future<Lesson> createLesson(Lesson lesson);
  Future<void> publishLesson(String lessonId, {bool publish = true});
  Future<void> reorderLessons({
    required String unitId,
    required List<String> orderedLessonIds,
  });
}

abstract class ILessonResourceRepository {
  Future<List<LessonResource>> fetchResourcesForLesson(String lessonId);
  Future<LessonResource> createResource(LessonResource resource);
  Future<void> deleteResource(String resourceId);
  Future<void> reorderResources({
    required String lessonId,
    required List<String> orderedResourceIds,
  });
  Future<String> getAuthorizedAssetUrl(String resourceId);
}

abstract class ILessonProgressRepository {
  Future<LessonProgress?> fetchProgressForLesson(String lessonId);
  Future<void> updateProgress({
    required String lessonId,
    required String status,
    int progressPercentage = 0,
    int lastPositionSeconds = 0,
    int timeSpentSeconds = 0,
  });
}
