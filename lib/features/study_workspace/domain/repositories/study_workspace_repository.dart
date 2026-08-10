import '../models/study_workspace_models.dart';

abstract class IStudyWorkspaceRepository {
  Future<StudyWorkspaceDraft> fetchDraft({
    required String studentId,
    required String lessonId,
  });

  Future<StudyWorkspaceDraft> fetchTeacherDraftForStudent({
    required String studentId,
    required String lessonId,
  });

  Future<StudyWorkspaceDraft> fetchTeacherDraft({
    required String teacherId,
    required String lessonId,
  });

  Future<void> saveNotebook({
    required String studentId,
    required String lessonId,
    required String content,
  });

  Future<void> saveCodeDraft({
    required String studentId,
    required String lessonId,
    required String code,
    String language = 'python',
  });

  Future<void> saveBoard({
    required String studentId,
    required String lessonId,
    required String boardData,
  });

  Future<void> saveTeacherBoard({
    required String teacherId,
    required String lessonId,
    required String boardData,
  });

  Future<List<Map<String, dynamic>>> fetchPdfAnnotations({
    required String studentId,
    required String lessonId,
  });

  Future<void> savePdfAnnotations({
    required String studentId,
    required String lessonId,
    required List<Map<String, dynamic>> annotations,
  });

  Future<List<Map<String, dynamic>>> fetchTeacherPdfAnnotationsForStudent({
    required String studentId,
    required String lessonId,
  });

  Future<List<Map<String, dynamic>>> fetchTeacherPdfAnnotations({
    required String teacherId,
    required String lessonId,
  });

  Future<void> saveTeacherPdfAnnotations({
    required String teacherId,
    required String lessonId,
    required List<Map<String, dynamic>> annotations,
  });

  Future<String?> startStudySession({
    required String studentId,
    required String lessonId,
    String? deviceId,
  });

  Future<void> finishStudySession({
    required String sessionId,
    required int durationSeconds,
    required int pagesRead,
  });

  Future<void> recordReplayEvent({
    required String sessionId,
    required String studentId,
    required String lessonId,
    required String eventType,
    required int eventOffsetMs,
    required Map<String, dynamic> payload,
  });

  Future<void> updatePageProgress({
    required String lessonId,
    required int page,
    required int progressPercentage,
  });
}
