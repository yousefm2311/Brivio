import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/study_workspace_models.dart';
import '../../domain/repositories/study_workspace_repository.dart';

class SupabaseStudyWorkspaceRepository implements IStudyWorkspaceRepository {
  final SupabaseClientWrapper _wrapper;

  SupabaseStudyWorkspaceRepository(this._wrapper);

  @override
  Future<StudyWorkspaceDraft> fetchDraft({
    required String studentId,
    required String lessonId,
  }) async {
    final notebook = await _wrapper.client
        .from('study_notebooks')
        .select('content')
        .eq('student_id', studentId)
        .eq('lesson_id', lessonId)
        .maybeSingle();
    final codeDraft = await _wrapper.client
        .from('study_code_drafts')
        .select('code')
        .eq('student_id', studentId)
        .eq('lesson_id', lessonId)
        .eq('language', 'python')
        .maybeSingle();

    return StudyWorkspaceDraft(
      notebookContent: notebook?['content'] as String? ?? '',
      code: codeDraft?['code'] as String? ?? '',
    );
  }

  @override
  Future<void> saveNotebook({
    required String studentId,
    required String lessonId,
    required String content,
  }) async {
    await _wrapper.client.from('study_notebooks').upsert({
      'student_id': studentId,
      'lesson_id': lessonId,
      'content': content,
      'sync_version': 1,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'student_id,lesson_id');
  }

  @override
  Future<void> saveCodeDraft({
    required String studentId,
    required String lessonId,
    required String code,
    String language = 'python',
  }) async {
    await _wrapper.client.from('study_code_drafts').upsert({
      'student_id': studentId,
      'lesson_id': lessonId,
      'language': language,
      'code': code,
      'sync_version': 1,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'student_id,lesson_id,language');
  }

  @override
  Future<void> updatePageProgress({
    required String lessonId,
    required int page,
    required int progressPercentage,
  }) async {
    await _wrapper.client.rpc(
      'update_lesson_progress',
      params: {
        'p_lesson_id': lessonId,
        'p_status': progressPercentage >= 100 ? 'completed' : 'in_progress',
        'p_progress_percentage': progressPercentage,
        'p_last_position_seconds': page,
        'p_time_spent_seconds': 0,
      },
    );
  }
}
