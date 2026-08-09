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
  final IStudyWorkspaceRepository? repository;

  bool _isLoaded = false;
  bool _isSaving = false;
  String _notebookText = '';
  String _codeText = '';
  String _boardData = '';
  int _currentPage;
  bool _isRunningCode = false;
  CodeRunResult? _lastRunResult;

  StudyWorkspaceViewModel({
    required this.lesson,
    this.studentId,
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
    final preferences = await SharedPreferences.getInstance();
    _notebookText = preferences.getString('$_notebookPrefix${lesson.id}') ?? '';
    _codeText = preferences.getString('$_codePrefix${lesson.id}') ?? '';
    _boardData = preferences.getString('$_boardPrefix${lesson.id}') ?? '';
    _currentPage =
        preferences.getInt('$_pagePrefix${lesson.id}') ?? lesson.lastPage;

    final draft = await _fetchCloudDraft();
    if (draft != null) {
      _notebookText = draft.notebookContent;
      _codeText = draft.code;
      _boardData = draft.boardData;
      await preferences.setString(
        '$_notebookPrefix${lesson.id}',
        _notebookText,
      );
      await preferences.setString('$_codePrefix${lesson.id}', _codeText);
      await preferences.setString('$_boardPrefix${lesson.id}', _boardData);
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> saveNotebook(String value) async {
    _notebookText = value;
    await _save(() async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('$_notebookPrefix${lesson.id}', value);
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
      await preferences.setString('$_codePrefix${lesson.id}', value);
      final currentStudentId = studentId;
      if (repository != null && currentStudentId != null) {
        try {
          await repository!.saveCodeDraft(
            studentId: currentStudentId,
            lessonId: lesson.id,
            code: value,
          );
        } catch (_) {}
      }
    });
  }

  Future<void> saveBoard(String value) async {
    _boardData = value;
    await _save(() async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('$_boardPrefix${lesson.id}', value);
      final currentStudentId = studentId;
      if (repository != null && currentStudentId != null) {
        try {
          await repository!.saveBoard(
            studentId: currentStudentId,
            lessonId: lesson.id,
            boardData: value,
          );
        } catch (_) {}
      }
    });
  }

  Future<void> goToPage(int page) async {
    final normalized = page.clamp(1, lesson.totalPages);
    _currentPage = normalized;
    await _save(() async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt('$_pagePrefix${lesson.id}', normalized);
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
        } catch (_) {}
      }
    });
  }

  void runCodePreview([String? code]) {
    if (code != null) _codeText = code;
    _lastRunResult = CodeRunResult(
      isSuccess: true,
      output: _buildPreviewOutput(_codeText),
    );
    notifyListeners();
  }

  Future<void> runCode({required String code, required String language}) async {
    _codeText = code;
    _isRunningCode = true;
    _lastRunResult = const CodeRunResult(
      isSuccess: true,
      output: 'Running code...',
    );
    notifyListeners();

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
      notifyListeners();
    }
  }

  Future<void> _save(Future<void> Function() action) async {
    _isSaving = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<StudyWorkspaceDraft?> _fetchCloudDraft() async {
    final currentStudentId = studentId;
    if (repository == null || currentStudentId == null) return null;
    try {
      return repository!.fetchDraft(
        studentId: currentStudentId,
        lessonId: lesson.id,
      );
    } catch (_) {
      return null;
    }
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
