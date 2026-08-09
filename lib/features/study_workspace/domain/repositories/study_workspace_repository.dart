import '../models/study_workspace_models.dart';

abstract class IStudyWorkspaceRepository {
  Future<StudyWorkspaceDraft> fetchDraft({
    required String studentId,
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

  Future<void> updatePageProgress({
    required String lessonId,
    required int page,
    required int progressPercentage,
  });
}
