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
    final board = await _wrapper.client
        .from('study_annotations')
        .select('geometry')
        .eq('student_id', studentId)
        .eq('lesson_id', lessonId)
        .eq('page_number', 1)
        .eq('annotation_type', 'freehand')
        .maybeSingle();

    return StudyWorkspaceDraft(
      notebookContent: notebook?['content'] as String? ?? '',
      code: codeDraft?['code'] as String? ?? '',
      boardData: board?['geometry']?['board_data'] as String? ?? '',
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
  Future<void> saveBoard({
    required String studentId,
    required String lessonId,
    required String boardData,
  }) async {
    await _wrapper.client
        .from('study_annotations')
        .delete()
        .eq('student_id', studentId)
        .eq('lesson_id', lessonId)
        .eq('page_number', 1)
        .eq('annotation_type', 'freehand');
    await _wrapper.client.from('study_annotations').insert({
      'student_id': studentId,
      'lesson_id': lessonId,
      'page_number': 1,
      'annotation_type': 'freehand',
      'color': '#1E40AF',
      'geometry': {'board_data': boardData},
      'content': 'Smart notebook board',
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPdfAnnotations({
    required String studentId,
    required String lessonId,
  }) async {
    final bookmarks = await _wrapper.client
        .from('study_bookmarks')
        .select('id, page_number, title, note, created_at')
        .eq('student_id', studentId)
        .eq('lesson_id', lessonId)
        .order('page_number');

    final annotations = await _wrapper.client
        .from('study_annotations')
        .select('id, page_number, annotation_type, content, created_at')
        .eq('student_id', studentId)
        .eq('lesson_id', lessonId)
        .inFilter('annotation_type', ['highlight', 'sticky_note'])
        .order('page_number');

    final drawings = await _wrapper.client
        .from('study_pdf_drawings')
        .select('id, page_number, strokes, updated_at')
        .eq('student_id', studentId)
        .eq('lesson_id', lessonId)
        .order('page_number');

    return [
      for (final row in bookmarks as List)
        {
          'id': (row as Map)['id'],
          'page': row['page_number'],
          'type': 'bookmark',
          'text': row['note'] ?? row['title'] ?? 'Bookmarked page',
          'created_at': row['created_at'],
        },
      for (final row in annotations as List)
        {
          'id': (row as Map)['id'],
          'page': row['page_number'],
          'type': row['annotation_type'] == 'sticky_note'
              ? 'note'
              : 'highlight',
          'text': row['content'] ?? '',
          'created_at': row['created_at'],
        },
      for (final row in drawings as List)
        {
          'id': (row as Map)['id'],
          'page': row['page_number'],
          'type': 'freehand',
          'text': 'Freehand drawing',
          'strokes': row['strokes'] ?? const [],
          'created_at': row['updated_at'],
        },
    ];
  }

  @override
  Future<void> savePdfAnnotations({
    required String studentId,
    required String lessonId,
    required List<Map<String, dynamic>> annotations,
  }) async {
    await _wrapper.client
        .from('study_bookmarks')
        .delete()
        .eq('student_id', studentId)
        .eq('lesson_id', lessonId);

    await _wrapper.client
        .from('study_annotations')
        .delete()
        .eq('student_id', studentId)
        .eq('lesson_id', lessonId)
        .inFilter('annotation_type', ['highlight', 'sticky_note']);

    await _wrapper.client
        .from('study_pdf_drawings')
        .delete()
        .eq('student_id', studentId)
        .eq('lesson_id', lessonId);

    final now = DateTime.now().toIso8601String();
    final bookmarks = annotations
        .where((annotation) => annotation['type'] == 'bookmark')
        .map(
          (annotation) => {
            'student_id': studentId,
            'lesson_id': lessonId,
            'page_number': annotation['page'] as int? ?? 1,
            'title': 'Page ${annotation['page'] ?? 1}',
            'note': annotation['text']?.toString() ?? 'Bookmarked page',
            'updated_at': now,
          },
        )
        .toList();
    final pdfAnnotations = annotations
        .where(
          (annotation) =>
              annotation['type'] != 'bookmark' &&
              annotation['type'] != 'freehand',
        )
        .map(
          (annotation) => {
            'student_id': studentId,
            'lesson_id': lessonId,
            'page_number': annotation['page'] as int? ?? 1,
            'annotation_type': annotation['type'] == 'note'
                ? 'sticky_note'
                : 'highlight',
            'color': annotation['type'] == 'note' ? '#38BDF8' : '#FACC15',
            'geometry': {'source': 'pdf_overlay'},
            'content': annotation['text']?.toString() ?? '',
            'updated_at': now,
          },
        )
        .toList();
    final drawings = annotations
        .where((annotation) => annotation['type'] == 'freehand')
        .map(
          (annotation) => {
            'student_id': studentId,
            'lesson_id': lessonId,
            'page_number': annotation['page'] as int? ?? 1,
            'strokes': annotation['strokes'] ?? const [],
            'updated_at': now,
          },
        )
        .toList();

    if (bookmarks.isNotEmpty) {
      await _wrapper.client.from('study_bookmarks').insert(bookmarks);
    }
    if (pdfAnnotations.isNotEmpty) {
      await _wrapper.client.from('study_annotations').insert(pdfAnnotations);
    }
    if (drawings.isNotEmpty) {
      await _wrapper.client.from('study_pdf_drawings').insert(drawings);
    }
  }

  @override
  Future<String?> startStudySession({
    required String studentId,
    required String lessonId,
    String? deviceId,
  }) async {
    final response = await _wrapper.client
        .from('study_sessions')
        .insert({
          'student_id': studentId,
          'lesson_id': lessonId,
          'device_id': deviceId,
          'started_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();
    return response['id'] as String?;
  }

  @override
  Future<void> finishStudySession({
    required String sessionId,
    required int durationSeconds,
    required int pagesRead,
  }) async {
    await _wrapper.client
        .from('study_sessions')
        .update({
          'ended_at': DateTime.now().toIso8601String(),
          'duration_seconds': durationSeconds,
          'pages_read': pagesRead,
        })
        .eq('id', sessionId);
  }

  @override
  Future<void> recordReplayEvent({
    required String sessionId,
    required String studentId,
    required String lessonId,
    required String eventType,
    required int eventOffsetMs,
    required Map<String, dynamic> payload,
  }) async {
    await _wrapper.client.from('study_replay_events').insert({
      'session_id': sessionId,
      'student_id': studentId,
      'lesson_id': lessonId,
      'event_type': eventType,
      'event_offset_ms': eventOffsetMs,
      'payload': payload,
    });
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
