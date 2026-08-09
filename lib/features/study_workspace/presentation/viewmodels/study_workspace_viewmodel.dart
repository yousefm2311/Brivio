import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  void runCodePreview() {
    final lines = _codeText
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .length;
    _lastRunResult = CodeRunResult(
      isSuccess: true,
      output:
          'Preview runner is ready.\n'
          'Analyzed $lines non-empty code lines.\n'
          'Real Python/C++ execution needs the Sandbox Server phase.',
    );
    notifyListeners();
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
}
