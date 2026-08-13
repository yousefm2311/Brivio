import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';

import '../../../../core/config/app_config.dart';
import '../../domain/models/study_workspace_models.dart';
import '../../domain/repositories/study_workspace_repository.dart';

class StudyWorkspaceViewModel extends ChangeNotifier {
  static const _notebookPrefix = 'study_workspace_notebook_';
  static const _codePrefix = 'study_workspace_code_';
  static const _boardPrefix = 'study_workspace_board_';
  static const _pagePrefix = 'study_workspace_page_';
  static const _visitedPagesPrefix = 'study_workspace_visited_pages_';

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
  String? _localPdfPath;
  String _loadingMessage = 'Preparing lesson workspace...';
  String? _loadError;
  StreamSubscription? _teacherDraftSubscription;
  bool _isDisposed = false;
  final DateTime _openedAt = DateTime.now();

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
  String? get localPdfPath => _localPdfPath;
  String get loadingMessage => _loadingMessage;
  String? get loadError => _loadError;

  void _setLoadingMessage(String message) {
    _loadingMessage = message;
    if (!_isDisposed) notifyListeners();
  }

  Future<void> load() async {
    _loadError = null;
    _setLoadingMessage('Loading your notes and saved board...');
    final userSuffix = teacherId ?? studentId ?? 'guest';
    final preferences = await SharedPreferences.getInstance();
    _notebookText =
        preferences.getString('$_notebookPrefix${lesson.id}_$userSuffix') ?? '';
    _codeText =
        preferences.getString('$_codePrefix${lesson.id}_$userSuffix') ?? '';
    _boardData =
        preferences.getString('$_boardPrefix${lesson.id}_$userSuffix') ?? '';
    _currentPage =
        preferences.getInt('$_pagePrefix${lesson.id}_$userSuffix') ??
        lesson.lastPage;

    Directory? appDir;
    try {
      appDir = await getApplicationDocumentsDirectory().timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {}

    // Use Hive for fallback or migration
    final boxName = 'study_workspace_cache';
    if (appDir != null) {
      try {
        final box = Hive.isBoxOpen(boxName)
            ? Hive.box(boxName)
            : await Hive.openBox(boxName, path: appDir.path);
        _boardData =
            box.get('$_boardPrefix${lesson.id}_$userSuffix') ?? _boardData;
      } catch (_) {}
    }

    // Check for cached PDF
    if (appDir == null) {
      final draft = await _fetchCloudDraft();
      if (draft != null) {
        _notebookText = draft.notebookContent;
        _codeText = draft.code;
        _boardData = draft.boardData;
      }

      if (studentId != null && repository != null) {
        await _mergeTeacherDraft();
        _subscribeToTeacherDraft();
      }

      _isLoaded = true;
      if (!_isDisposed) notifyListeners();
      return;
    }

    final pdfFile = File('${appDir.path}/pdf_${lesson.id}.pdf');
    if (await pdfFile.exists()) {
      _localPdfPath = pdfFile.path;
    } else if (lesson.pdfUrl != null) {
      // Download PDF if not cached
      try {
        _setLoadingMessage('Downloading lesson PDF...');
        final response = await http
            .get(Uri.parse(lesson.pdfUrl!))
            .timeout(const Duration(seconds: 25));
        if (response.statusCode == 200) {
          await pdfFile.writeAsBytes(response.bodyBytes);
          _localPdfPath = pdfFile.path;
        } else {
          _loadError =
              'The PDF could not be downloaded. Please check the file link and try again.';
        }
      } on TimeoutException {
        _loadError =
            'The PDF download took too long. Please check your connection and try again.';
      } catch (_) {
        _loadError =
            'The PDF could not be opened. Please check your connection and try again.';
      }
    }

    _setLoadingMessage('Syncing teacher board and your workspace...');
    final draft = await _fetchCloudDraft();
    if (draft != null) {
      _notebookText = draft.notebookContent;
      _codeText = draft.code;
      _boardData = draft.boardData;

      final userSuffix = teacherId ?? studentId ?? 'guest';
      await preferences.setString(
        '$_notebookPrefix${lesson.id}_$userSuffix',
        _notebookText,
      );
      await preferences.setString(
        '$_codePrefix${lesson.id}_$userSuffix',
        _codeText,
      );
      await preferences.setString(
        '$_boardPrefix${lesson.id}_$userSuffix',
        _boardData,
      );
    }

    if (studentId != null && repository != null) {
      await _mergeTeacherDraft();
      _subscribeToTeacherDraft();
    }

    _isLoaded = true;
    if (!_isDisposed) notifyListeners();
  }

  void _subscribeToTeacherDraft() {
    final currentStudentId = studentId;
    final currentRepository = repository;
    if (currentStudentId == null || currentRepository == null) return;

    _teacherDraftSubscription?.cancel();
    _teacherDraftSubscription = currentRepository
        .listenToTeacherDraftForStudent(
          studentId: currentStudentId,
          lessonId: lesson.id,
          groupId: lesson.groupId,
        )
        .listen(
          (draft) async {
            await _mergeTeacherDraft(teacherDraft: draft);
            if (!_isDisposed) notifyListeners();
          },
          onError: (error) {
            debugPrint('Error listening to teacher draft: $error');
          },
        );
  }

  Future<void> _mergeTeacherDraft({StudyWorkspaceDraft? teacherDraft}) async {
    if (studentId == null || repository == null) return;
    try {
      teacherDraft ??= await repository!.fetchTeacherDraftForStudent(
        studentId: studentId!,
        lessonId: lesson.id,
        groupId: lesson.groupId,
      );
      List<dynamic> studentStrokes = [];
      if (_boardData.isNotEmpty) {
        final std = jsonDecode(_boardData);
        if (std is Map && std['strokes'] is List) {
          studentStrokes = std['strokes']
              .where(
                (s) =>
                    s is Map &&
                    s['is_teacher'] != true &&
                    s['isTeacher'] != true,
              )
              .toList();
        }
      }

      if (teacherDraft.boardData.isEmpty) {
        _boardData = jsonEncode({'strokes': studentStrokes});
        return;
      }

      if (teacherDraft.boardData.isNotEmpty) {
        final decoded = jsonDecode(teacherDraft.boardData);
        if (decoded is Map && decoded['strokes'] is List) {
          final strokes = (decoded['strokes'] as List).whereType<Map>().map((
            s,
          ) {
            final st = Map<String, dynamic>.from(s);
            st['isTeacher'] = true;
            st['is_teacher'] = true;
            return st;
          }).toList();

          _boardData = jsonEncode({
            'strokes': [...strokes, ...studentStrokes],
          });
        }
      }
    } catch (_) {}
  }

  Future<void> saveNotebook(String value) async {
    _notebookText = value;
    await _save(() async {
      final preferences = await SharedPreferences.getInstance();
      final userSuffix = teacherId ?? studentId ?? 'guest';
      await preferences.setString(
        '$_notebookPrefix${lesson.id}_$userSuffix',
        value,
      );
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
      final userSuffix = teacherId ?? studentId ?? 'guest';
      await preferences.setString(
        '$_codePrefix${lesson.id}_$userSuffix',
        value,
      );
      final currentStudentId = studentId;
      if (repository != null && currentStudentId != null) {
        try {
          await repository!.saveCodeDraft(
            studentId: currentStudentId,
            lessonId: lesson.id,
            code: value,
          );
        } catch (e, st) {
          debugPrint('Failed to save code draft: $e\n$st');
        }
      }
    });
  }

  Future<void> saveBoard(String value) async {
    final currentStudentId = studentId;
    final currentTeacherId = teacherId;
    final valueToPersist = value;
    final valueToDisplay = currentStudentId != null && currentTeacherId == null
        ? _mergeExistingTeacherStrokes(value)
        : value;
    _boardData = valueToDisplay;
    await _save(() async {
      final preferences = await SharedPreferences.getInstance();
      final userSuffix = teacherId ?? studentId ?? 'guest';
      await preferences.setString(
        '$_boardPrefix${lesson.id}_$userSuffix',
        valueToDisplay,
      );

      final boxName = 'study_workspace_cache';
      try {
        final box = Hive.isBoxOpen(boxName)
            ? Hive.box(boxName)
            : await Hive.openBox(
                boxName,
                path: (await getApplicationDocumentsDirectory()).path,
              );
        await box.put('$_boardPrefix${lesson.id}_$userSuffix', valueToDisplay);
      } catch (_) {}

      if (repository != null) {
        try {
          if (currentTeacherId != null) {
            await repository!.saveTeacherBoard(
              teacherId: currentTeacherId,
              lessonId: lesson.id,
              boardData: valueToPersist,
            );
          } else if (currentStudentId != null) {
            await repository!.saveBoard(
              studentId: currentStudentId,
              lessonId: lesson.id,
              boardData: valueToPersist,
            );
          }
        } catch (e, st) {
          debugPrint('Failed to save study board: $e\n$st');
        }
      }
    });
  }

  Future<void> goToPage(int page) async {
    final normalized = page.clamp(1, lesson.totalPages);
    _currentPage = normalized;
    await _save(() async {
      final preferences = await SharedPreferences.getInstance();
      final userSuffix = teacherId ?? studentId ?? 'guest';
      await preferences.setInt(
        '$_pagePrefix${lesson.id}_$userSuffix',
        normalized,
      );
      if (repository != null && studentId != null) {
        final visitedKey = '$_visitedPagesPrefix${lesson.id}_$userSuffix';
        final visitedPages = {
          ...preferences.getStringList(visitedKey) ?? const <String>[],
          '$normalized',
        };
        await preferences.setStringList(visitedKey, visitedPages.toList());

        final pagesProgress = lesson.totalPages <= 0
            ? 0
            : ((visitedPages.length / lesson.totalPages) * 100).round().clamp(
                0,
                100,
              );
        final elapsedSeconds = DateTime.now().difference(_openedAt).inSeconds;
        final minimumStudySeconds = (lesson.totalPages * 20).clamp(60, 600);
        final progress = lesson.totalPages <= 0
            ? 0
            : pagesProgress >= 100 && elapsedSeconds < minimumStudySeconds
            ? 95
            : pagesProgress;
        try {
          await repository!.updatePageProgress(
            lessonId: lesson.id,
            page: normalized,
            progressPercentage: progress,
          );
        } catch (e, st) {
          debugPrint('Failed to update lesson progress: $e\n$st');
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
      _lastRunResult = await _runCompilerExplorer(
        code: code,
        language: language,
      );
    } finally {
      _isRunningCode = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  String _mergeExistingTeacherStrokes(String studentBoardData) {
    try {
      final teacherStrokes = <dynamic>[];
      if (_boardData.isNotEmpty) {
        final current = jsonDecode(_boardData);
        if (current is Map && current['strokes'] is List) {
          teacherStrokes.addAll(
            (current['strokes'] as List).where(
              (stroke) =>
                  stroke is Map &&
                  (stroke['is_teacher'] == true || stroke['isTeacher'] == true),
            ),
          );
        }
      }

      final nextStudentStrokes = <dynamic>[];
      if (studentBoardData.isNotEmpty) {
        final next = jsonDecode(studentBoardData);
        if (next is Map && next['strokes'] is List) {
          nextStudentStrokes.addAll(
            (next['strokes'] as List).where(
              (stroke) =>
                  stroke is Map &&
                  stroke['is_teacher'] != true &&
                  stroke['isTeacher'] != true,
            ),
          );
        }
      }

      return jsonEncode({
        'strokes': [...teacherStrokes, ...nextStudentStrokes],
      });
    } catch (_) {
      return studentBoardData;
    }
  }

  Future<CodeRunResult> _runCompilerExplorer({
    required String code,
    required String language,
  }) async {
    final compilerId = switch (language.toLowerCase()) {
      'dart' => 'dart373',
      'python' || 'py' => 'python311',
      'js' || 'javascript' => 'v8113',
      'cpp' || 'c++' => 'g132',
      _ => 'python311',
    };

    try {
      final response = await http
          .post(
            Uri.parse('https://godbolt.org/api/compiler/$compilerId/compile'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'source': code,
              'compiler': compilerId,
              'options': {
                'userArguments': '',
                'executeParameters': {'args': [], 'stdin': ''},
                'compilerOptions': {'executorRequest': true},
                'filters': {'execute': true},
                'tools': [],
                'libraries': [],
              },
            }),
          )
          .timeout(const Duration(seconds: 16));

      if (response.statusCode != 200) {
        return CodeRunResult(
          isSuccess: false,
          output:
              'Execution failed. Compiler API status: ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final output = StringBuffer();
      for (final section in ['stdout', 'stderr']) {
        final lines = decoded[section];
        if (lines is List) {
          for (final line in lines.whereType<Map>()) {
            final text = line['text']?.toString() ?? '';
            if (text.trim().isNotEmpty) output.writeln(text);
          }
        }
      }
      final buildResult = decoded['buildResult'];
      if (buildResult is Map && buildResult['stderr'] is List) {
        for (final line in (buildResult['stderr'] as List).whereType<Map>()) {
          final text = line['text']?.toString() ?? '';
          if (text.trim().isNotEmpty &&
              !text.startsWith('<Compilation failed>')) {
            output.writeln(text);
          }
        }
      }

      final text = output.toString().trim();
      return CodeRunResult(
        isSuccess: true,
        output: text.isEmpty ? 'Program finished with no output.' : text,
      );
    } catch (fallbackError) {
      return CodeRunResult(
        isSuccess: false,
        output:
            'Sandbox and Compiler Explorer are not reachable.\n\n'
            '${_buildPreviewOutput(code)}',
      );
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
        'Use Run code for real Python/C++/Dart execution through the Sandbox Server.';
  }
}
