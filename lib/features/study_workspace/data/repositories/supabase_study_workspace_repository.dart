import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    try {
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

      final draft = StudyWorkspaceDraft(
        notebookContent: notebook?['content'] as String? ?? '',
        code: codeDraft?['code'] as String? ?? '',
        boardData: board?['geometry']?['board_data'] as String? ?? '',
      );

      final boxName = 'study_workspace_cache';
      final box = Hive.isBoxOpen(boxName)
          ? Hive.box(boxName)
          : await Hive.openBox(boxName);
      await box.put(
        'draft_${lessonId}_$studentId',
        jsonEncode({
          'notebookContent': draft.notebookContent,
          'code': draft.code,
          'boardData': draft.boardData,
        }),
      );

      return draft;
    } catch (_) {
      final boxName = 'study_workspace_cache';
      final box = Hive.isBoxOpen(boxName)
          ? Hive.box(boxName)
          : await Hive.openBox(boxName);
      final cached = box.get('draft_${lessonId}_$studentId');
      if (cached != null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        return StudyWorkspaceDraft(
          notebookContent: data['notebookContent'] ?? '',
          code: data['code'] ?? '',
          boardData: data['boardData'] ?? '',
        );
      }
      return const StudyWorkspaceDraft(
        notebookContent: '',
        code: '',
        boardData: '',
      );
    }
  }

  @override
  Future<StudyWorkspaceDraft> fetchTeacherDraftForStudent({
    required String studentId,
    required String lessonId,
  }) async {
    try {
      final annotationBoards = await _wrapper.client
          .rpc(
            'get_student_teacher_study_annotations',
            params: {'p_lesson_id': lessonId, 'p_student_id': studentId},
          )
          .eq('page_number', 1)
          .eq('annotation_type', 'freehand');

      final pdfDrawingBoards = await _wrapper.client
          .rpc(
            'get_student_teacher_study_pdf_drawings',
            params: {'p_lesson_id': lessonId, 'p_student_id': studentId},
          )
          .eq('page_number', 1);

      final boardData = _mergeBoardDataFromRows([
        ..._asRowList(annotationBoards),
        ..._asRowList(pdfDrawingBoards),
      ]);
      if (boardData.isNotEmpty) {
        return StudyWorkspaceDraft(
          notebookContent: '',
          code: '',
          boardData: boardData,
        );
      }

      final directBoards = await _wrapper.client
          .from('teacher_study_annotations')
          .select('geometry')
          .eq('lesson_id', lessonId)
          .eq('page_number', 1)
          .eq('annotation_type', 'freehand');

      final directPdfDrawings = await _wrapper.client
          .from('teacher_study_pdf_drawings')
          .select('strokes')
          .eq('lesson_id', lessonId)
          .eq('page_number', 1);

      return StudyWorkspaceDraft(
        notebookContent: '',
        code: '',
        boardData: _mergeBoardDataFromRows([
          ..._asRowList(directBoards),
          ..._asRowList(directPdfDrawings),
        ]),
      );
    } catch (e) {
      return const StudyWorkspaceDraft(
        notebookContent: '',
        code: '',
        boardData: '',
      );
    }
  }

  @override
  Stream<StudyWorkspaceDraft> listenToTeacherDraftForStudent({
    required String studentId,
    required String lessonId,
  }) {
    late final StreamController<StudyWorkspaceDraft> controller;
    RealtimeChannel? channel;

    controller = StreamController<StudyWorkspaceDraft>(
      onListen: () {
        channel = _wrapper.client.channel(
          'public:teacher_study_workspace:lesson_$lessonId',
        );

        Future<void> pushLatestDraft() async {
          final draft = await fetchTeacherDraftForStudent(
            studentId: studentId,
            lessonId: lessonId,
          );
          if (!controller.isClosed) {
            controller.add(draft);
          }
        }

        channel!
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'teacher_study_annotations',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'lesson_id',
                value: lessonId,
              ),
              callback: (_) => unawaited(pushLatestDraft()),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'teacher_study_pdf_drawings',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'lesson_id',
                value: lessonId,
              ),
              callback: (_) => unawaited(pushLatestDraft()),
            )
            .subscribe();
      },
      onCancel: () {
        channel?.unsubscribe();
        controller.close();
      },
    );

    return controller.stream;
  }

  @override
  Future<StudyWorkspaceDraft> fetchTeacherDraft({
    required String teacherId,
    required String lessonId,
  }) async {
    final boards = await _wrapper.client
        .from('teacher_study_annotations')
        .select('geometry')
        .eq('teacher_id', teacherId)
        .eq('lesson_id', lessonId)
        .eq('page_number', 1)
        .eq('annotation_type', 'freehand');

    return StudyWorkspaceDraft(
      notebookContent: '',
      code: '',
      boardData: _mergeBoardDataFromRows(boards),
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
  Future<void> saveTeacherBoard({
    required String teacherId,
    required String lessonId,
    required String boardData,
  }) async {
    try {
      await _wrapper.client.rpc(
        'save_teacher_study_board',
        params: {
          'p_teacher_id': teacherId,
          'p_lesson_id': lessonId,
          'p_board_data': boardData,
        },
      );
      return;
    } catch (_) {
      // Older databases may not have the RPC until the latest migration is run.
    }

    await _wrapper.client
        .from('teacher_study_annotations')
        .delete()
        .eq('teacher_id', teacherId)
        .eq('lesson_id', lessonId)
        .eq('page_number', 1)
        .eq('annotation_type', 'freehand');
    await _wrapper.client.from('teacher_study_annotations').insert({
      'teacher_id': teacherId,
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
    try {
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

      final result = [
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

      final boxName = 'study_workspace_cache';
      final box = Hive.isBoxOpen(boxName)
          ? Hive.box(boxName)
          : await Hive.openBox(boxName);
      await box.put(
        'pdf_annotations_${lessonId}_$studentId',
        jsonEncode(result),
      );

      return result;
    } catch (_) {
      final boxName = 'study_workspace_cache';
      final box = Hive.isBoxOpen(boxName)
          ? Hive.box(boxName)
          : await Hive.openBox(boxName);
      final cached = box.get('pdf_annotations_${lessonId}_$studentId');
      if (cached != null) {
        final List<dynamic> data = jsonDecode(cached);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTeacherPdfAnnotationsForStudent({
    required String studentId,
    required String lessonId,
  }) async {
    try {
      final annotations = await _wrapper.client
          .rpc(
            'get_student_teacher_study_annotations',
            params: {'p_lesson_id': lessonId, 'p_student_id': studentId},
          )
          .inFilter('annotation_type', ['highlight', 'sticky_note'])
          .order('page_number');

      final drawings = await _wrapper.client
          .rpc(
            'get_student_teacher_study_pdf_drawings',
            params: {'p_lesson_id': lessonId, 'p_student_id': studentId},
          )
          .order('page_number');

      final mapped = _mapTeacherAnnotations(annotations, drawings);
      if (mapped.isNotEmpty) return mapped;

      final directAnnotations = await _wrapper.client
          .from('teacher_study_annotations')
          .select('id, page_number, annotation_type, content, created_at')
          .eq('lesson_id', lessonId)
          .inFilter('annotation_type', ['highlight', 'sticky_note'])
          .order('page_number');

      final directDrawings = await _wrapper.client
          .from('teacher_study_pdf_drawings')
          .select('id, page_number, strokes, updated_at')
          .eq('lesson_id', lessonId)
          .order('page_number');

      return _mapTeacherAnnotations(directAnnotations, directDrawings);
    } catch (_) {
      try {
        final directAnnotations = await _wrapper.client
            .from('teacher_study_annotations')
            .select('id, page_number, annotation_type, content, created_at')
            .eq('lesson_id', lessonId)
            .inFilter('annotation_type', ['highlight', 'sticky_note'])
            .order('page_number');

        final directDrawings = await _wrapper.client
            .from('teacher_study_pdf_drawings')
            .select('id, page_number, strokes, updated_at')
            .eq('lesson_id', lessonId)
            .order('page_number');

        return _mapTeacherAnnotations(directAnnotations, directDrawings);
      } catch (_) {
        return [];
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTeacherPdfAnnotations({
    required String teacherId,
    required String lessonId,
  }) async {
    final annotations = await _wrapper.client
        .from('teacher_study_annotations')
        .select('id, page_number, annotation_type, content, created_at')
        .eq('teacher_id', teacherId)
        .eq('lesson_id', lessonId)
        .inFilter('annotation_type', ['highlight', 'sticky_note'])
        .order('page_number');

    final drawings = await _wrapper.client
        .from('teacher_study_pdf_drawings')
        .select('id, page_number, strokes, updated_at')
        .eq('teacher_id', teacherId)
        .eq('lesson_id', lessonId)
        .order('page_number');

    return _mapTeacherAnnotations(annotations, drawings);
  }

  List<Map<String, dynamic>> _mapTeacherAnnotations(
    dynamic annotations,
    dynamic drawings,
  ) {
    return [
      for (final row in annotations as List)
        {
          'id': (row as Map)['id'],
          'page': row['page_number'],
          'type': row['annotation_type'] == 'sticky_note'
              ? 'note'
              : 'highlight',
          'text': row['content'] ?? '',
          'created_at': row['created_at'],
          'is_teacher': true,
        },
      for (final row in drawings as List)
        {
          'id': (row as Map)['id'],
          'page': row['page_number'],
          'type': 'freehand',
          'text': 'Freehand drawing',
          'strokes': row['strokes'] ?? const [],
          'created_at': row['updated_at'],
          'is_teacher': true,
        },
    ];
  }

  @override
  Future<void> saveTeacherPdfAnnotations({
    required String teacherId,
    required String lessonId,
    required List<Map<String, dynamic>> annotations,
  }) async {
    await _wrapper.client
        .from('teacher_study_annotations')
        .delete()
        .eq('teacher_id', teacherId)
        .eq('lesson_id', lessonId)
        .inFilter('annotation_type', ['highlight', 'sticky_note']);

    await _wrapper.client
        .from('teacher_study_pdf_drawings')
        .delete()
        .eq('teacher_id', teacherId)
        .eq('lesson_id', lessonId);

    final highlightAnnotations = annotations
        .where((a) => a['type'] == 'highlight')
        .toList();
    final noteAnnotations = annotations
        .where((a) => a['type'] == 'note')
        .toList();
    final freehandAnnotations = annotations
        .where((a) => a['type'] == 'freehand')
        .toList();

    if (highlightAnnotations.isNotEmpty || noteAnnotations.isNotEmpty) {
      final toInsert = [
        ...highlightAnnotations.map(
          (a) => {
            'teacher_id': teacherId,
            'lesson_id': lessonId,
            'page_number': a['page'],
            'annotation_type': 'highlight',
            'content': a['text'],
            'created_at': a['created_at'],
            'updated_at': a['created_at'],
          },
        ),
        ...noteAnnotations.map(
          (a) => {
            'teacher_id': teacherId,
            'lesson_id': lessonId,
            'page_number': a['page'],
            'annotation_type': 'sticky_note',
            'content': a['text'],
            'created_at': a['created_at'],
            'updated_at': a['created_at'],
          },
        ),
      ];
      await _wrapper.client.from('teacher_study_annotations').insert(toInsert);
    }

    if (freehandAnnotations.isNotEmpty) {
      final pageStrokes = <int, List<Map<String, dynamic>>>{};
      final pageTimestamps = <int, String>{};

      for (final a in freehandAnnotations) {
        final page = a['page'] as int;
        pageStrokes.putIfAbsent(page, () => []);
        pageStrokes[page]!.addAll(
          List<Map<String, dynamic>>.from(a['strokes'] ?? []),
        );
        pageTimestamps[page] =
            (a['created_at'] ?? DateTime.now().toIso8601String()).toString();
      }

      final toInsert = pageStrokes.entries
          .map(
            (e) => {
              'teacher_id': teacherId,
              'lesson_id': lessonId,
              'page_number': e.key,
              'strokes': e.value,
              'updated_at': pageTimestamps[e.key],
              'created_at': pageTimestamps[e.key],
            },
          )
          .toList();

      await _wrapper.client.from('teacher_study_pdf_drawings').insert(toInsert);
    }
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

String _mergeBoardDataFromRows(dynamic rows) {
  final strokes = <dynamic>[];
  final list = _asRowList(rows);
  for (final raw in list) {
    if (raw is! Map) continue;
    final geometry = raw['geometry'];
    final boardData = geometry is Map ? geometry['board_data'] : null;
    if (boardData is String && boardData.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(boardData);
        if (decoded is Map && decoded['strokes'] is List) {
          strokes.addAll(decoded['strokes'] as List);
        }
      } catch (_) {}
    }

    final rawStrokes = raw['strokes'];
    if (rawStrokes is List && rawStrokes.isNotEmpty) {
      strokes.addAll(rawStrokes);
    }
  }
  return strokes.isEmpty ? '' : jsonEncode({'strokes': strokes});
}

List<dynamic> _asRowList(dynamic rows) {
  if (rows is List) return rows;
  if (rows == null) return const [];
  return [rows];
}
