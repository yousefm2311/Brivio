import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../domain/models/study_workspace_models.dart';
import '../../domain/repositories/study_workspace_repository.dart';

class StudyWorkspaceViewModel extends ChangeNotifier {
  static const _notebookPrefix = 'study_workspace_notebook_';
  static const _codePrefix = 'study_workspace_code_';
  static const _boardPrefix = 'study_workspace_board_';
  static const _pagePrefix = 'study_workspace_page_';

  final StudyLessonSummary lesson;
  final String? studentId;
  final String? teacherId;
  final IStudyWorkspaceRepository? repository;

  bool _isLoaded = false;
  bool _isSaving = false;
  String _notebookText = '';
  String _codeText = '';
  String _boardData = '';
  int _currentPage;
  bool _isRunningCode = false;
  CodeRunResult? _lastRunResult;
  StreamSubscription? _teacherDraftSubscription;
  bool _isDisposed = false;

  StudyWorkspaceViewModel({
    required this.lesson,
    this.studentId,
    this.teacherId,
    this.repository,
  }) : _currentPage = lesson.lastPage;

  bool get isLoaded => _isLoaded;
  bool get isSaving => _isSaving;
  String get notebookText => _notebookText;
  String get codeText => _codeText;
  String get boardData => _boardData;
  int get currentPage => _currentPage;
  bool get isRunningCode => _isRunningCode;
  CodeRunResult? get lastRunResult => _lastRunResult;

  Future<void> load() async {
    final userSuffix = '${teacherId ?? studentId ?? 'guest'}';
    final preferences = await SharedPreferences.getInstance();
    _notebookText = preferences.getString('$_notebookPrefix${lesson.id}_$userSuffix') ?? '';
    _codeText = preferences.getString('$_codePrefix${lesson.id}_$userSuffix') ?? '';
    _boardData = preferences.getString('$_boardPrefix${lesson.id}_$userSuffix') ?? '';
    _currentPage =
        preferences.getInt('$_pagePrefix${lesson.id}_$userSuffix') ?? lesson.lastPage;

    final draft = await _fetchCloudDraft();
    if (draft != null) {
      _notebookText = draft.notebookContent;
      _codeText = draft.code;
      _boardData = draft.boardData;
      
      if (studentId != null && repository != null) {
        // Fetch initial state
        await _mergeTeacherDraft();

        _teacherDraftSubscription?.cancel();
        // Subscribe to real-time updates
        _teacherDraftSubscription = repository!.listenToTeacherDraftForStudent(
          studentId: studentId!,
          lessonId: lesson.id,
        ).listen((draft) async {
          await _mergeTeacherDraft();
          if (!_isDisposed) notifyListeners();
        });
      }

      final userSuffix = '${teacherId ?? studentId ?? 'guest'}';
      await preferences.setString(
        '$_notebookPrefix${lesson.id}_$userSuffix',
        _notebookText,
      );
      await preferences.setString('$_codePrefix${lesson.id}_$userSuffix', _codeText);
      await preferences.setString('$_boardPrefix${lesson.id}_$userSuffix', _boardData);
    }

    _isLoaded = true;
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _mergeTeacherDraft() async {
    if (studentId == null || repository == null) return;
    try {
      final teacherDraft = await repository!.fetchTeacherDraftForStudent(
        studentId: studentId!,
        lessonId: lesson.id,
      );
      if (teacherDraft.boardData.isNotEmpty) {
        final decoded = jsonDecode(teacherDraft.boardData);
        if (decoded is Map && decoded['strokes'] is List) {
          final strokes = (decoded['strokes'] as List).whereType<Map>().map((s) {
            final st = Map<String, dynamic>.from(s);
            st['is_teacher'] = true;
            return st;
          }).toList();
          
          List<dynamic> studentStrokes = [];
          if (_boardData.isNotEmpty) {
            final std = jsonDecode(_boardData);
            if (std is Map && std['strokes'] is List) studentStrokes = std['strokes'].where((s) => s is Map && s['is_teacher'] != true).toList();
          }
          _boardData = jsonEncode({'strokes': [...strokes, ...studentStrokes]});
        }
      }
    } catch (_) {}
  }

  Future<void> saveNotebook(String value) async {
    _notebookText = value;
    await _save(() async {
      final preferences = await SharedPreferences.getInstance();
      final userSuffix = '${teacherId ?? studentId ?? 'guest'}';
      await preferences.setString('$_notebookPrefix${lesson.id}_$userSuffix', value);
      final currentStudentId = studentId;
      if (repository != null && currentStudentId != null) {
        try {
          await repository!.saveNotebook(
            studentId: currentStudentId,
            lessonId: lesson.id,
            content: value,
          );
        } catch (_) {}
      }
    });
  }

  Future<void> saveCode(String value) async {
    _codeText = value;
    await _save(() async {
      final preferences = await SharedPreferences.getInstance();
      final userSuffix = '${teacherId ?? studentId ?? 'guest'}';
      await preferences.setString('$_codePrefix${lesson.id}_$userSuffix', value);
      final currentStudentId = studentId;
      if (repository != null && currentStudentId != null) {
        try {
          await repository!.saveCodeDraft(
            studentId: currentStudentId,
            lessonId: lesson.id,
            code: value,
          );
        } catch (e, st) {
          print('=== DEBUG ERROR IN SAVE CODEDRAFT: $e\n$st ===');
        }
      }
    });
  }

  Future<void> saveBoard(String value) async {
    _boardData = value;
    await _save(() async {
      final preferences = await SharedPreferences.getInstance();
      final userSuffix = '${teacherId ?? studentId ?? 'guest'}';
      await preferences.setString('$_boardPrefix${lesson.id}_$userSuffix', value);
      final currentStudentId = studentId;
      final currentTeacherId = teacherId;
      if (repository != null) {
        try {
          if (currentTeacherId != null) {
            await repository!.saveTeacherBoard(
              teacherId: currentTeacherId,
              lessonId: lesson.id,
              boardData: value,
            );
          } else if (currentStudentId != null) {
            await repository!.saveBoard(
              studentId: currentStudentId,
              lessonId: lesson.id,
              boardData: value,
            );
          }
        } catch (e, st) {
          print('=== DEBUG ERROR IN SAVEBOARD: $e\n$st ===');
        }
      }
    });
  }

  Future<void> goToPage(int page) async {
    final normalized = page.clamp(1, lesson.totalPages);
    _currentPage = normalized;
    await _save(() async {
      final preferences = await SharedPreferences.getInstance();
      final userSuffix = '${teacherId ?? studentId ?? 'guest'}';
      await preferences.setInt('$_pagePrefix${lesson.id}_$userSuffix', normalized);
      if (repository != null && studentId != null) {
        final progress = lesson.totalPages <= 0
            ? 0
            : ((normalized / lesson.totalPages) * 100).round().clamp(0, 100);
        try {
          await repository!.updatePageProgress(
            lessonId: lesson.id,
            page: normalized,
            progressPercentage: progress,
          );
        } catch (e, st) {
          print('=== DEBUG ERROR IN UPDATEPAGEPROGRESS: $e\n$st ===');
        }
      }
    });
  }

  void runCodePreview([String? code]) {
    if (code != null) _codeText = code;
    _lastRunResult = CodeRunResult(
      isSuccess: true,
      output: _buildPreviewOutput(_codeText),
    );
    if (!_isDisposed) notifyListeners();
  }

  Future<void> runCode({required String code, required String language}) async {
    _codeText = code;
    _isRunningCode = true;
    _lastRunResult = const CodeRunResult(
      isSuccess: true,
      output: 'Running code...',
    );
    if (!_isDisposed) notifyListeners();

    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.effectiveCodeSandboxUrl}/run'),
            headers: AppConfig.codeSandboxHeaders,
            body: jsonEncode({'language': language, 'code': code, 'stdin': ''}),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final stdout = (decoded['stdout'] as String?) ?? '';
      final stderr = (decoded['stderr'] as String?) ?? '';
      final exitCode = decoded['exitCode'];
      final durationMs = decoded['durationMs'];
      final success = decoded['success'] == true && response.statusCode == 200;
      final buffer = StringBuffer()
        ..writeln(success ? 'Execution finished.' : 'Execution failed.')
        ..writeln('Exit code: ${exitCode ?? 'unknown'}')
        ..writeln('Duration: ${durationMs ?? 'unknown'} ms');
      if (stdout.trim().isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('stdout:')
          ..write(stdout.trimRight());
      }
      if (stderr.trim().isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('stderr:')
          ..write(stderr.trimRight());
      }
      _lastRunResult = CodeRunResult(
        isSuccess: success,
        output: buffer.toString().trimRight(),
      );
    } catch (error) {
      _lastRunResult = CodeRunResult(
        isSuccess: false,
        output:
            'Sandbox server is not reachable.\n'
            'Start sandbox_server/server.py for local trusted execution, or use the Docker production sandbox on a server.\n'
            'The Visualize button still works offline for studying the code flow.\n\n'
            '${_buildPreviewOutput(code)}',
      );
    } finally {
      _isRunningCode = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _teacherDraftSubscription?.cancel();
    super.dispose();
  }

  Future<void> _save(Future<void> Function() action) async {
    _isSaving = true;
    if (!_isDisposed) notifyListeners();
    try {
      await action();
    } finally {
      _isSaving = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<StudyWorkspaceDraft?> _fetchCloudDraft() async {
    final currentStudentId = studentId;
    final currentTeacherId = teacherId;
    if (repository == null) return null;
    
    try {
      if (currentTeacherId != null) {
        return await repository!.fetchTeacherDraft(
          teacherId: currentTeacherId,
          lessonId: lesson.id,
        );
      } else if (currentStudentId != null) {
        return await repository!.fetchDraft(
          studentId: currentStudentId,
          lessonId: lesson.id,
        );
      }
    } catch (_) {}
    return null;
  }

  String _buildPreviewOutput(String code) {
    final lines = code
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .length;
    return 'Preview runner is ready.\n'
        'Analyzed $lines non-empty code lines.\n'
        'Use Run code for real Python/C++ execution through the Sandbox Server.';
  }
}
