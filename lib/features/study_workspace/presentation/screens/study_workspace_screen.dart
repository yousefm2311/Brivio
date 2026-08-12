import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../domain/models/study_workspace_models.dart';
import '../../domain/repositories/study_workspace_repository.dart';
import '../viewmodels/study_workspace_viewmodel.dart';

class StudyWorkspaceScreen extends StatefulWidget {
  final StudyLessonSummary lesson;
  final String? studentId;
  final String? teacherId;
  final IStudyWorkspaceRepository? repository;

  const StudyWorkspaceScreen({
    super.key,
    required this.lesson,
    this.studentId,
    this.teacherId,
    this.repository,
  });

  @override
  State<StudyWorkspaceScreen> createState() => _StudyWorkspaceScreenState();
}

class _StudyWorkspaceScreenState extends State<StudyWorkspaceScreen> {
  late final StudyWorkspaceViewModel _viewModel;
  late final TextEditingController _notebookController;
  late final TextEditingController _codeController;
  Timer? _notebookDebounce;
  Timer? _codeDebounce;
  Timer? _boardDebounce;
  List<_BoardStroke> _boardStrokes = [];
  List<_PdfAnnotation> _pdfAnnotations = [];
  bool _pdfAnnotationsLoaded = false;
  String? _studySessionId;
  DateTime? _studySessionStartedAt;
  final Set<int> _visitedPages = {};

  static const _inkColors = [
    Color(0xFF1D4ED8),
    Color(0xFF111827),
    Color(0xFFDC2626),
    Color(0xFF16A34A),
    Color(0xFFEAB308),
  ];
  Color _selectedColor = _inkColors.first;
  bool _eraser = false;
  _BoardStroke? _activeStroke;
  bool _isFabMenuOpen = false;
  bool _showBoard = false;
  bool _isPanMode = false;
  late final TransformationController _boardTransformationController;

  void _startStroke(DragStartDetails details) {
    setState(() {
      _activeStroke = _BoardStroke(
        color: _eraser ? Colors.white : _selectedColor,
        width: _eraser ? 18 : 4,
        points: [details.localPosition],
      );
    });
  }

  void _appendStroke(DragUpdateDetails details) {
    final stroke = _activeStroke;
    if (stroke == null) return;
    setState(() {
      _activeStroke = stroke.copyWith(
        points: [...stroke.points, details.localPosition],
      );
    });
  }

  void _endStroke([DragEndDetails? _]) {
    final stroke = _activeStroke;
    if (stroke == null || stroke.points.length < 2) {
      setState(() => _activeStroke = null);
      return;
    }
    _queueBoardSave([..._boardStrokes, stroke]);
    setState(() => _activeStroke = null);
  }

  void _clearBoard() {
    _queueBoardSave([]);
  }

  @override
  void initState() {
    super.initState();
    _viewModel = StudyWorkspaceViewModel(
      lesson: widget.lesson,
      studentId: widget.studentId,
      teacherId: widget.teacherId,
      repository: widget.repository,
    );
    _notebookController = TextEditingController();
    _codeController = TextEditingController();
    _boardTransformationController = TransformationController();
    
    // Center the board by default on the 4000x4000 canvas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      _boardTransformationController.value = Matrix4.identity()
        ..translate(-2000.0 + size.width / 2, -2000.0 + size.height / 2);
    });

    _viewModel.addListener(_syncLoadedText);
    _viewModel.load();
  }

  @override
  void dispose() {
    _notebookDebounce?.cancel();
    _codeDebounce?.cancel();
    _boardDebounce?.cancel();
    _viewModel.removeListener(_syncLoadedText);
    _finishStudySession();
    _viewModel.dispose();
    _notebookController.dispose();
    _codeController.dispose();
    _boardTransformationController.dispose();
    super.dispose();
  }

  void _syncLoadedText() {
    if (!_viewModel.isLoaded) return;
    if (_notebookController.text.isEmpty &&
        _viewModel.notebookText.isNotEmpty) {
      _notebookController.text = _viewModel.notebookText;
    }
    if (_codeController.text.isEmpty && _viewModel.codeText.isNotEmpty) {
      _codeController.text = _viewModel.codeText;
    }
    final newBoardStrokes = _decodeBoard(_viewModel.boardData);
    if (newBoardStrokes.length != _boardStrokes.length) {
      setState(() => _boardStrokes = newBoardStrokes);
    }
    if (!_pdfAnnotationsLoaded) {
      _pdfAnnotationsLoaded = true;
      _loadPdfAnnotations();
      _startStudySession();
    }
  }

  void _queueNotebookSave(String value) {
    _notebookDebounce?.cancel();
    _notebookDebounce = Timer(const Duration(milliseconds: 450), () {
      _viewModel.saveNotebook(value);
      _recordReplayEvent('notebook_saved', {'length': value.length});
    });
  }

  void _queueCodeSave(String value) {
    _codeDebounce?.cancel();
    _codeDebounce = Timer(const Duration(milliseconds: 450), () {
      _viewModel.saveCode(value);
    });
  }

  void _queueBoardSave(List<_BoardStroke> strokes) {
    setState(() => _boardStrokes = strokes);
    _boardDebounce?.cancel();
    _boardDebounce = Timer(const Duration(milliseconds: 450), () {
      final strokesToSave = widget.teacherId == null 
        ? strokes.where((s) => !s.isTeacher).toList()
        : strokes;
      _viewModel.saveBoard(_encodeBoard(strokesToSave));
      _recordReplayEvent('board_changed', {'stroke_count': strokes.length});
    });
  }

  Future<void> _startStudySession() async {
    final repository = widget.repository;
    final studentId = widget.studentId;
    if (repository == null || studentId == null || _studySessionId != null) {
      return;
    }
    try {
      final sessionId = await repository.startStudySession(
        studentId: studentId,
        lessonId: widget.lesson.id,
        deviceId: Theme.of(context).platform.name,
      );
      if (!mounted || sessionId == null) return;
      _studySessionId = sessionId;
      _studySessionStartedAt = DateTime.now();
      _visitedPages.add(_viewModel.currentPage);
      _recordReplayEvent('lesson_opened', {
        'page': _viewModel.currentPage,
        'lesson_title': widget.lesson.title,
      });
    } catch (_) {}
  }

  void _finishStudySession() {
    final repository = widget.repository;
    final sessionId = _studySessionId;
    final startedAt = _studySessionStartedAt;
    if (repository == null || sessionId == null || startedAt == null) return;
    final duration = DateTime.now().difference(startedAt).inSeconds;
    unawaited(
      repository
          .finishStudySession(
            sessionId: sessionId,
            durationSeconds: duration,
            pagesRead: _visitedPages.length,
          )
          .catchError((_) {}),
    );
  }

  void _recordReplayEvent(String eventType, Map<String, dynamic> payload) {
    final repository = widget.repository;
    final studentId = widget.studentId;
    final sessionId = _studySessionId;
    final startedAt = _studySessionStartedAt;
    if (repository == null ||
        studentId == null ||
        sessionId == null ||
        startedAt == null) {
      return;
    }
    unawaited(
      repository
          .recordReplayEvent(
            sessionId: sessionId,
            studentId: studentId,
            lessonId: widget.lesson.id,
            eventType: eventType,
            eventOffsetMs: DateTime.now().difference(startedAt).inMilliseconds,
            payload: payload,
          )
          .catchError((_) {}),
    );
  }

  Future<void> _loadPdfAnnotations() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_pdfAnnotationKey);
    if (!mounted) return;
    final localAnnotations = _decodePdfAnnotations(raw ?? '');
    setState(() => _pdfAnnotations = localAnnotations);

    final repository = widget.repository;
    final studentId = widget.studentId;
    final teacherId = widget.teacherId;
    if (repository == null || (studentId == null && teacherId == null)) return;
    try {
      List<Map<String, dynamic>> cloudRows = [];
      if (teacherId != null) {
        cloudRows = await repository.fetchTeacherPdfAnnotations(
          teacherId: teacherId,
          lessonId: widget.lesson.id,
        );
      } else if (studentId != null) {
        cloudRows = await repository.fetchPdfAnnotations(
          studentId: studentId,
          lessonId: widget.lesson.id,
        );
        final teacherRows = await repository.fetchTeacherPdfAnnotationsForStudent(
          studentId: studentId,
          lessonId: widget.lesson.id,
        );
        cloudRows = [...cloudRows, ...teacherRows];
      }
      final cloudAnnotations = cloudRows
          .map(_PdfAnnotation.fromJson)
          .where((annotation) => annotation.id.isNotEmpty)
          .toList();
      if (cloudAnnotations.isEmpty || !mounted) return;
      setState(() => _pdfAnnotations = cloudAnnotations);
      await preferences.setString(
        _pdfAnnotationKey,
        _encodePdfAnnotations(cloudAnnotations),
      );
    } catch (_) {}
  }

  Future<void> _savePdfAnnotations(List<_PdfAnnotation> annotations) async {
    setState(() => _pdfAnnotations = annotations);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _pdfAnnotationKey,
      _encodePdfAnnotations(annotations),
    );
    final repository = widget.repository;
    final currentStudentId = widget.studentId;
    final currentTeacherId = widget.teacherId;
    if (repository == null) return;
    try {
      List<Map<String, dynamic>> annotationsToSave = [];
      
      if (currentTeacherId != null) {
        annotationsToSave = annotations.map((a) => a.toJson()).toList();
        await repository.saveTeacherPdfAnnotations(
          teacherId: currentTeacherId,
          lessonId: widget.lesson.id,
          annotations: annotationsToSave,
        );
      } else if (currentStudentId != null) {
        annotationsToSave = annotations
            .map((a) {
              if (a.type == _PdfAnnotationType.freehand && a.strokes.isNotEmpty) {
                final studentStrokes = a.strokes.where((s) => !s.isTeacher).toList();
                if (studentStrokes.isEmpty) return null;
                return _PdfAnnotation(
                  id: a.id,
                  page: a.page,
                  type: a.type,
                  text: a.text,
                  createdAt: a.createdAt,
                  strokes: studentStrokes,
                  isTeacher: false,
                ).toJson();
              }
              return a.isTeacher ? null : a.toJson();
            })
            .whereType<Map<String, dynamic>>()
            .toList();
            
        await repository.savePdfAnnotations(
          studentId: currentStudentId,
          lessonId: widget.lesson.id,
          annotations: annotationsToSave,
        );
      }
    } catch (_) {}
  }

  String get _pdfAnnotationKey =>
      'study_workspace_pdf_annotations_${widget.lesson.id}_${widget.teacherId ?? widget.studentId ?? 'guest'}';

  Future<void> _addStickyNote() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _StickyNoteDialog(),
    );
    if (text == null || text.isEmpty) return;
    await _savePdfAnnotations([
      ..._pdfAnnotations,
      _PdfAnnotation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        page: _viewModel.currentPage,
        type: _PdfAnnotationType.note,
        text: text,
        createdAt: DateTime.now(),
        isTeacher: widget.teacherId != null,
      ),
    ]);
    _recordReplayEvent('pdf_note_added', {
      'page': _viewModel.currentPage,
      'length': text.length,
    });
  }

  Future<void> _addHighlight() async {
    await _savePdfAnnotations([
      ..._pdfAnnotations,
      _PdfAnnotation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        page: _viewModel.currentPage,
        type: _PdfAnnotationType.highlight,
        text: 'Highlighted section',
        createdAt: DateTime.now(),
        isTeacher: widget.teacherId != null,
      ),
    ]);
    _recordReplayEvent('pdf_highlight_added', {'page': _viewModel.currentPage});
  }

  Future<void> _toggleBookmark() async {
    final page = _viewModel.currentPage;
    final existing = _pdfAnnotations.where(
      (annotation) =>
          annotation.page == page &&
          annotation.type == _PdfAnnotationType.bookmark,
    );
    if (existing.isNotEmpty) {
      await _savePdfAnnotations(
        _pdfAnnotations
            .where(
              (annotation) =>
                  !(annotation.page == page &&
                      annotation.type == _PdfAnnotationType.bookmark),
            )
            .toList(),
      );
      _recordReplayEvent('pdf_bookmark_removed', {'page': page});
      return;
    }
    await _savePdfAnnotations([
      ..._pdfAnnotations,
      _PdfAnnotation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        page: page,
        type: _PdfAnnotationType.bookmark,
        text: 'Bookmarked page',
        createdAt: DateTime.now(),
        isTeacher: widget.teacherId != null,
      ),
    ]);
    _recordReplayEvent('pdf_bookmark_added', {'page': page});
  }

  Future<void> _deletePdfAnnotation(String id) async {
    final annotation = _pdfAnnotations.firstWhere(
      (a) => a.id == id, 
      orElse: () => _PdfAnnotation(id: '', page: 0, type: _PdfAnnotationType.note, text: '', createdAt: DateTime.now())
    );
    if (annotation.id.isEmpty) return;
    if (widget.teacherId == null && annotation.isTeacher) return;

    await _savePdfAnnotations(
      _pdfAnnotations.where((a) => a.id != id).toList(),
    );
    _recordReplayEvent('pdf_annotation_deleted', {'id': id});
  }

  Future<void> _savePdfFreehand(int page, List<_BoardStroke> strokes) async {
    final withoutPageDrawing = _pdfAnnotations
        .where(
          (annotation) =>
              !(annotation.page == page &&
                  annotation.type == _PdfAnnotationType.freehand),
        )
        .toList();
    final nextAnnotations = strokes.isEmpty
        ? withoutPageDrawing
        : [
            ...withoutPageDrawing,
            _PdfAnnotation(
              id: 'freehand_${widget.lesson.id}_$page',
              page: page,
              type: _PdfAnnotationType.freehand,
              text: 'Freehand drawing',
              createdAt: DateTime.now(),
              strokes: strokes,
              isTeacher: widget.teacherId != null,
            ),
          ];
    await _savePdfAnnotations(nextAnnotations);
    _recordReplayEvent('pdf_freehand_changed', {
      'page': page,
      'stroke_count': strokes.length,
    });
  }

  Future<void> _goToPage(int delta) async {
    await _viewModel.goToPage(_viewModel.currentPage + delta);
    _visitedPages.add(_viewModel.currentPage);
    _recordReplayEvent('page_changed', {'page': _viewModel.currentPage});
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        if (!_viewModel.isLoaded) {
          return Scaffold(
            backgroundColor: bgColor,
            body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        
        final hasPdf = widget.lesson.pdfUrl != null;
        final showPdf = hasPdf && !_showBoard;

        return Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: [
              if (showPdf)
                Positioned.fill(
                  child: _PdfPane(
                    viewModel: _viewModel,
                    annotations: _pdfAnnotations,
                    onAddNote: _addStickyNote,
                    onAddHighlight: _addHighlight,
                    onToggleBookmark: _toggleBookmark,
                    onDeleteAnnotation: _deletePdfAnnotation,
                    onFreehandChanged: _savePdfFreehand,
                    onPreviousPage: () => _goToPage(-1),
                    onNextPage: () => _goToPage(1),
                    teacherId: widget.teacherId,
                  ),
                ),

              if (!showPdf)
                Positioned.fill(
                  child: _DrawingBoard(
                    strokes: _activeStroke == null ? _boardStrokes : [..._boardStrokes, _activeStroke!],
                    onPanStart: _startStroke,
                    onPanUpdate: _appendStroke,
                    onPanEnd: _endStroke,
                    isTransparent: false,
                    isPanMode: _isPanMode,
                    transformationController: _boardTransformationController,
                    canvasSize: const Size(4000, 4000),
                  ),
                ),

              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  borderRadius: BorderRadius.circular(32),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.lesson.title,
                              style: AppTypography.labelLarge(
                                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ).copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 12, color: AppColors.info),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.lesson.estimatedMinutes} min',
                                  style: const TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: widget.lesson.progress,
                                      minHeight: 4,
                                      backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _viewModel.isSaving
                                      ? const SizedBox(
                                          width: 14, height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                        )
                                      : const Icon(Icons.cloud_done_rounded, size: 16, color: AppColors.success),
                                ),
                                const SizedBox(width: 4),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (hasPdf)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GlassCard(
                      padding: const EdgeInsets.all(4),
                      borderRadius: BorderRadius.circular(28),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ToggleButton(
                            title: 'PDF',
                            isSelected: !_showBoard,
                            onTap: () => setState(() => _showBoard = false),
                          ),
                          _ToggleButton(
                            title: 'Board',
                            isSelected: _showBoard,
                            onTap: () => setState(() => _showBoard = true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                right: 24,
                child: _FloatingToolMenu(
                  isOpen: _isFabMenuOpen,
                  onToggle: () => setState(() => _isFabMenuOpen = !_isFabMenuOpen),
                  selectedColor: _selectedColor,
                  eraser: _eraser,
                  onColorSelected: (c) => setState(() { _selectedColor = c; _eraser = false; _isPanMode = false; }),
                  onToggleEraser: () => setState(() { _eraser = !_eraser; if (_eraser) _isPanMode = false; }),
                  isPanMode: _isPanMode,
                  onTogglePanMode: () => setState(() { _isPanMode = !_isPanMode; if (_isPanMode) _eraser = false; }),
                  onClear: _clearBoard,
                  hasPdf: showPdf,
                  onPrevPage: () => _goToPage(-1),
                  onNextPage: () => _goToPage(1),
                  currentPage: _viewModel.currentPage,
                  totalPages: widget.lesson.totalPages,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _ToggleButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected 
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }
}

class _FloatingToolMenu extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onToggle;
  final Color selectedColor;
  final bool eraser;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onToggleEraser;
  final bool isPanMode;
  final VoidCallback onTogglePanMode;
  final VoidCallback onClear;
  final bool hasPdf;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final int currentPage;
  final int totalPages;

  static const _colors = [
    Color(0xFF1D4ED8),
    Color(0xFF111827),
    Color(0xFFDC2626),
    Color(0xFF16A34A),
    Color(0xFFEAB308),
  ];

  const _FloatingToolMenu({
    required this.isOpen,
    required this.onToggle,
    required this.selectedColor,
    required this.eraser,
    required this.onColorSelected,
    required this.onToggleEraser,
    required this.isPanMode,
    required this.onTogglePanMode,
    required this.onClear,
    required this.hasPdf,
    required this.onPrevPage,
    required this.onNextPage,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isOpen) ...[
          if (hasPdf) ...[
            GlassCard(
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: currentPage > 1 ? onPrevPage : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'Previous Page',
                  ),
                  Text('${currentPage} / ${totalPages}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    onPressed: currentPage < totalPages ? onNextPage : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'Next Page',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          GlassCard(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final color in _colors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ToolColorDot(
                      color: color,
                      isSelected: !eraser && selectedColor == color,
                      onTap: () => onColorSelected(color),
                    ),
                  ),
                Container(height: 1, width: 24, color: theme.dividerColor, margin: const EdgeInsets.only(bottom: 12)),
                IconButton(
                  onPressed: onToggleEraser,
                  icon: Icon(Icons.cleaning_services_rounded, color: eraser && !isPanMode ? AppColors.primary : null),
                  tooltip: 'Eraser',
                ),
                IconButton(
                  onPressed: onTogglePanMode,
                  icon: Icon(Icons.pan_tool_rounded, color: isPanMode ? AppColors.primary : null),
                  tooltip: 'Pan Tool',
                ),
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  tooltip: 'Clear Board',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          onPressed: onToggle,
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
          foregroundColor: isDark ? AppColors.primary : Colors.white,
          elevation: isOpen ? 0 : 4,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: child.key == const ValueKey('close') ? Tween<double>(begin: -0.125, end: 0).animate(anim) : Tween<double>(begin: 0.125, end: 0).animate(anim),
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: isOpen
                ? const Icon(Icons.close_rounded, key: ValueKey('close'))
                : const Icon(Icons.edit_rounded, key: ValueKey('open')),
          ),
        ),
      ],
    );
  }
}

class _ToolColorDot extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolColorDot({required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            if (isSelected) BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8)
          ],
        ),
      ),
    );
  }
}

 

class _PdfPane extends StatefulWidget {
  final StudyWorkspaceViewModel viewModel;
  final List<_PdfAnnotation> annotations;
  final VoidCallback onAddNote;
  final VoidCallback onAddHighlight;
  final VoidCallback onToggleBookmark;
  final ValueChanged<String> onDeleteAnnotation;
  final void Function(int page, List<_BoardStroke> strokes) onFreehandChanged;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final String? teacherId;

  const _PdfPane({
    required this.viewModel,
    required this.annotations,
    required this.onAddNote,
    required this.onAddHighlight,
    required this.onToggleBookmark,
    required this.onDeleteAnnotation,
    required this.onFreehandChanged,
    required this.onPreviousPage,
    required this.onNextPage,
    this.teacherId,
  });

  @override
  State<_PdfPane> createState() => _PdfPaneState();
}

class _PdfPaneState extends State<_PdfPane> {
  static const _inkColors = [
    Color(0xFF1D4ED8),
    Color(0xFF111827),
    Color(0xFFDC2626),
    Color(0xFF16A34A),
    Color(0xFFEAB308),
  ];

  Color _selectedColor = _inkColors.first;
  double _strokeWidth = 4;
  bool _drawMode = false;
  bool _eraser = false;
  _BoardStroke? _activeStroke;

  List<_BoardStroke> _pageStrokes(List<_PdfAnnotation> annotations, int page) {
    return annotations
        .where(
          (annotation) =>
              annotation.page == page &&
              annotation.type == _PdfAnnotationType.freehand,
        )
        .expand((annotation) => annotation.strokes)
        .toList();
  }

  void _startStroke(DragStartDetails details) {
    if (!_drawMode) return;
    setState(() {
      _activeStroke = _BoardStroke(
        color: _eraser ? Colors.white : _selectedColor,
        width: _eraser ? _strokeWidth * 3.2 : _strokeWidth,
        points: [details.localPosition],
      );
    });
  }

  void _appendStroke(DragUpdateDetails details) {
    final stroke = _activeStroke;
    if (!_drawMode || stroke == null) return;
    setState(() {
      _activeStroke = stroke.copyWith(
        points: [...stroke.points, details.localPosition],
      );
    });
  }

  void _endStroke([DragEndDetails? _]) {
    final stroke = _activeStroke;
    if (stroke == null || stroke.points.length < 2) {
      setState(() => _activeStroke = null);
      return;
    }
    final page = widget.viewModel.currentPage;
    final strokes = [..._pageStrokes(widget.annotations, page), stroke];
    widget.onFreehandChanged(page, strokes);
    setState(() => _activeStroke = null);
  }

  void _undoStroke() {
    final page = widget.viewModel.currentPage;
    final strokes = _pageStrokes(widget.annotations, page);
    if (strokes.isEmpty) return;
    
    if (widget.teacherId == null) {
      final studentStrokes = strokes.where((s) => !s.isTeacher).toList();
      if (studentStrokes.isEmpty) return;
      final teacherStrokes = strokes.where((s) => s.isTeacher).toList();
      widget.onFreehandChanged(
          page, [...teacherStrokes, ...studentStrokes.take(studentStrokes.length - 1)]);
    } else {
      widget.onFreehandChanged(page, strokes.take(strokes.length - 1).toList());
    }
  }

  void _clearStrokes() {
    final page = widget.viewModel.currentPage;
    if (widget.teacherId == null) {
      final strokes = _pageStrokes(widget.annotations, page);
      final teacherStrokes = strokes.where((s) => s.isTeacher).toList();
      widget.onFreehandChanged(page, teacherStrokes);
    } else {
      widget.onFreehandChanged(page, []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final lesson = viewModel.lesson;
    if (lesson.pdfUrl == null) {
      return _MissingPdfState(lesson: lesson);
    }

    final pageAnnotations = widget.annotations
        .where((annotation) => annotation.page == viewModel.currentPage)
        .toList();
    final hasBookmark = pageAnnotations.any(
      (annotation) => annotation.type == _PdfAnnotationType.bookmark,
    );
    final highlights = pageAnnotations
        .where((annotation) => annotation.type == _PdfAnnotationType.highlight)
        .toList();
    final pageStrokes = _pageStrokes(widget.annotations, viewModel.currentPage);
    final visibleStrokes = _activeStroke == null
        ? pageStrokes
        : [...pageStrokes, _activeStroke!];

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: _SignedPdfViewer(
            url: lesson.pdfUrl!,
            localPath: viewModel.localPdfPath,
            pageNumber: viewModel.currentPage,
            pageOverlaysBuilder: (context, pageRect, page) {
              final pageNum = page.pageNumber;
              final pStrokes = _pageStrokes(widget.annotations, pageNum);
              final isActive = pageNum == viewModel.currentPage;
              
              final pageVisibleStrokes = (isActive && _activeStroke != null)
                  ? [...pStrokes, _activeStroke!]
                  : pStrokes;

              return [
                IgnorePointer(
                  ignoring: !(_drawMode && isActive),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: _PdfFreehandLayer(
                      strokes: pageVisibleStrokes,
                      onPanStart: _startStroke,
                      onPanUpdate: _appendStroke,
                      onPanEnd: _endStroke,
                    ),
                  ),
                ),
              ];
            },
          ),
        ),
        for (var i = 0; i < highlights.length.clamp(0, 4); i++)
          PositionedDirectional(
            start: 52,
            end: 52,
            top: 132.0 + (i * 46),
            child: IgnorePointer(
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF176).withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFFACC15).withValues(alpha: .55),
                  ),
                ),
              ),
            ),
          ),
        // Pagination removed as it's now in the Floating UI
        PositionedDirectional(
          end: 16,
          top: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: hasBookmark ? 'Remove bookmark' : 'Bookmark page',
                  onPressed: widget.onToggleBookmark,
                  icon: Icon(
                    hasBookmark ? Icons.bookmark : Icons.bookmark_border,
                    color: hasBookmark ? AppColors.warning : null,
                  ),
                ),
                IconButton(
                  tooltip: 'Highlight',
                  onPressed: widget.onAddHighlight,
                  icon: const Icon(Icons.format_color_fill),
                ),
                IconButton(
                  tooltip: 'Sticky note',
                  onPressed: widget.onAddNote,
                  icon: const Icon(Icons.sticky_note_2_outlined),
                ),
              ],
            ),
          ),
        ),
        if (_drawMode)
          PositionedDirectional(
            end: 16,
            top: 72,
            child: _PdfDrawingToolbar(
              colors: _inkColors,
              selectedColor: _selectedColor,
              strokeWidth: _strokeWidth,
              eraser: _eraser,
              canUndo: pageStrokes.isNotEmpty,
              onColorSelected: (color) => setState(() {
                _selectedColor = color;
                _eraser = false;
              }),
              onStrokeWidthChanged: (value) =>
                  setState(() => _strokeWidth = value),
              onEraserChanged: (value) => setState(() => _eraser = value),
              onUndo: _undoStroke,
              onClear: pageStrokes.isEmpty ? null : _clearStrokes,
            ),
          ),
        PositionedDirectional(
          start: 16,
          end: 16,
          bottom: 16,
          child: _PdfAnnotationTray(
            annotations: pageAnnotations,
            onDelete: widget.onDeleteAnnotation,
          ),
        ),
      ],
    );
  }
}

class _MissingPdfState extends StatelessWidget {
  final StudyLessonSummary lesson;

  const _MissingPdfState({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              lesson.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'No PDF resource has been published for this lesson yet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfFreehandLayer extends StatelessWidget {
  final List<_BoardStroke> strokes;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  const _PdfFreehandLayer({
    required this.strokes,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: CustomPaint(
        painter: _PdfFreehandPainter(strokes),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PdfFreehandPainter extends CustomPainter {
  final List<_BoardStroke> strokes;

  const _PdfFreehandPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PdfFreehandPainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}

class _PdfDrawingToolbar extends StatelessWidget {
  final List<Color> colors;
  final Color selectedColor;
  final double strokeWidth;
  final bool eraser;
  final bool canUndo;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<double> onStrokeWidthChanged;
  final ValueChanged<bool> onEraserChanged;
  final VoidCallback onUndo;
  final VoidCallback? onClear;

  const _PdfDrawingToolbar({
    required this.colors,
    required this.selectedColor,
    required this.strokeWidth,
    required this.eraser,
    required this.canUndo,
    required this.onColorSelected,
    required this.onStrokeWidthChanged,
    required this.onEraserChanged,
    required this.onUndo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .96),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ToggleButtons(
              isSelected: [!eraser, eraser],
              onPressed: (index) => onEraserChanged(index == 1),
              children: const [
                Tooltip(message: 'Pen', child: Icon(Icons.edit)),
                Tooltip(
                  message: 'Eraser',
                  child: Icon(Icons.cleaning_services),
                ),
              ],
            ),
            for (final color in colors)
              _ColorDot(
                color: color,
                isSelected: !eraser && color == selectedColor,
                onTap: () => onColorSelected(color),
              ),
            SizedBox(
              width: 130,
              child: Slider(
                min: 2,
                max: 12,
                divisions: 5,
                value: strokeWidth,
                onChanged: onStrokeWidthChanged,
              ),
            ),
            IconButton(
              tooltip: 'Undo stroke',
              onPressed: canUndo ? onUndo : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Clear page drawing',
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfAnnotationTray extends StatelessWidget {
  final List<_PdfAnnotation> annotations;
  final ValueChanged<String> onDelete;

  const _PdfAnnotationTray({required this.annotations, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final visible = annotations
        .where(
          (annotation) =>
              annotation.type != _PdfAnnotationType.bookmark &&
              annotation.type != _PdfAnnotationType.freehand,
        )
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 180),
        child: Card(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final annotation = visible[index];
              return ListTile(
                dense: true,
                leading: Icon(
                  annotation.type == _PdfAnnotationType.highlight
                      ? Icons.format_color_fill
                      : Icons.sticky_note_2_outlined,
                  color: annotation.type == _PdfAnnotationType.highlight
                      ? AppColors.warning
                      : AppColors.info,
                ),
                title: Text(
                  annotation.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(annotation.dateLabel),
                trailing: IconButton(
                  tooltip: 'Delete annotation',
                  onPressed: () => onDelete(annotation.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _PdfAnnotationType { bookmark, highlight, note, freehand }

class _PdfAnnotation {
  final String id;
  final int page;
  final _PdfAnnotationType type;
  final String text;
  final DateTime createdAt;
  final List<_BoardStroke> strokes;
  final bool isTeacher;

  const _PdfAnnotation({
    required this.id,
    required this.page,
    required this.type,
    required this.text,
    required this.createdAt,
    this.strokes = const [],
    this.isTeacher = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'page': page,
    'type': type.name,
    'text': text,
    if (type == _PdfAnnotationType.freehand)
      'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
    'isTeacher': isTeacher,
  };

  factory _PdfAnnotation.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString() ?? 'note';
    return _PdfAnnotation(
      id: json['id']?.toString() ?? '',
      page: int.tryParse(json['page']?.toString() ?? '') ?? 1,
      type: _PdfAnnotationType.values.firstWhere(
        (type) => type.name == rawType,
        orElse: () => _PdfAnnotationType.note,
      ),
      text: json['text']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      strokes: _decodeStrokeList(json['strokes']),
      isTeacher:
          json['isTeacher'] as bool? ?? json['is_teacher'] as bool? ?? false,
    );
  }

  String get dateLabel {
    final month = createdAt.month.toString().padLeft(2, '0');
    final day = createdAt.day.toString().padLeft(2, '0');
    return '${createdAt.year}-$month-$day';
  }
}

List<_BoardStroke> _decodeStrokeList(dynamic raw) {
  final rawStrokes = raw is List ? raw : const [];
  return rawStrokes
      .whereType<Map>()
      .map((s) => _BoardStroke.fromJson(Map<String, dynamic>.from(s)))
      .toList();
}

String _encodePdfAnnotations(List<_PdfAnnotation> annotations) {
  return jsonEncode({
    'annotations': annotations
        .map((annotation) => annotation.toJson())
        .toList(),
  });
}

List<_PdfAnnotation> _decodePdfAnnotations(String raw) {
  if (raw.trim().isEmpty) return [];
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rawAnnotations = decoded['annotations'] as List<dynamic>? ?? [];
    return rawAnnotations
        .whereType<Map>()
        .map(
          (annotation) =>
              _PdfAnnotation.fromJson(Map<String, dynamic>.from(annotation)),
        )
        .where((annotation) => annotation.id.isNotEmpty)
        .toList();
  } catch (_) {
    return [];
  }
}

class _SignedPdfViewer extends StatefulWidget {
  final String url;
  final String? localPath;
  final int pageNumber;
  final PdfPageOverlaysBuilder? pageOverlaysBuilder;

  const _SignedPdfViewer({
    required this.url,
    this.localPath,
    required this.pageNumber,
    this.pageOverlaysBuilder,
  });

  @override
  State<_SignedPdfViewer> createState() => _SignedPdfViewerState();
}

class _SignedPdfViewerState extends State<_SignedPdfViewer> {
  late final PdfViewerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  @override
  void didUpdateWidget(covariant _SignedPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber && _controller.isReady) {
      _controller.goToPage(
        pageNumber: widget.pageNumber,
        duration: const Duration(milliseconds: 180),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: widget.localPath != null
          ? PdfViewer.file(
              widget.localPath!,
              controller: _controller,
              initialPageNumber: widget.pageNumber,
              params: PdfViewerParams(
                pageOverlaysBuilder: widget.pageOverlaysBuilder,
                onViewerReady: (document, controller) {
                  controller.goToPage(
                    pageNumber: widget.pageNumber,
                    duration: Duration.zero,
                  );
                },
                loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
                  final progress = totalBytes == null || totalBytes == 0
                      ? null
                      : bytesDownloaded / totalBytes;
                  return Center(
                    child: SizedBox(
                      width: 260,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 12),
                          Text(context.tr('Loading PDF...')),
                        ],
                      ),
                    ),
                  );
                },
                errorBannerBuilder: (context, error, stackTrace, documentRef) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.picture_as_pdf_outlined,
                            color: AppColors.error,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('PDF failed to load'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          : PdfViewer.uri(
              Uri.parse(widget.url),
              controller: _controller,
              initialPageNumber: widget.pageNumber,
              params: PdfViewerParams(
                pageOverlaysBuilder: widget.pageOverlaysBuilder,
                onViewerReady: (document, controller) {
                  controller.goToPage(
                    pageNumber: widget.pageNumber,
                    duration: Duration.zero,
                  );
                },
                loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
                  final progress = totalBytes == null || totalBytes == 0
                      ? null
                      : bytesDownloaded / totalBytes;
                  return Center(
                    child: SizedBox(
                      width: 260,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 12),
                          Text(context.tr('Loading PDF...')),
                        ],
                      ),
                    ),
                  );
                },
                errorBannerBuilder: (context, error, stackTrace, documentRef) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.picture_as_pdf_outlined,
                            color: AppColors.error,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('PDF failed to load'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      ),
    );
  }
}

class _NotebookPane extends StatefulWidget {
  final TextEditingController controller;
  final List<_BoardStroke> strokes;
  final ValueChanged<String> onChanged;
  final ValueChanged<List<_BoardStroke>> onBoardChanged;

  const _NotebookPane({
    required this.controller,
    required this.strokes,
    required this.onChanged,
    required this.onBoardChanged,
  });

  @override
  State<_NotebookPane> createState() => _NotebookPaneState();
}

class _NotebookPaneState extends State<_NotebookPane> {
  static const _colors = [
    Color(0xFF1E40AF),
    Color(0xFF111827),
    Color(0xFFDC2626),
    Color(0xFF16A34A),
    Color(0xFFEAB308),
  ];

  Color _selectedColor = _colors.first;
  bool _eraser = false;
  _BoardStroke? _activeStroke;

  List<_BoardStroke> get _strokes => widget.strokes;

  void _startStroke(DragStartDetails details) {
    final local = details.localPosition;
    setState(() {
      _activeStroke = _BoardStroke(
        color: _eraser ? Colors.white : _selectedColor,
        width: _eraser ? 18 : 4,
        points: [local],
      );
    });
  }

  void _appendStroke(DragUpdateDetails details) {
    final stroke = _activeStroke;
    if (stroke == null) return;
    setState(() {
      _activeStroke = stroke.copyWith(
        points: [...stroke.points, details.localPosition],
      );
    });
  }

  void _endStroke([DragEndDetails? _]) {
    final stroke = _activeStroke;
    if (stroke == null || stroke.points.length < 2) {
      setState(() => _activeStroke = null);
      return;
    }
    widget.onBoardChanged([..._strokes, stroke]);
    setState(() => _activeStroke = null);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              onChanged: widget.onChanged,
              decoration: const InputDecoration(
                labelText: 'Smart Notebook',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            width: double.infinity,
            child: _DrawingBoard(
              strokes: _activeStroke == null
                  ? _strokes
                  : [..._strokes, _activeStroke!],
              onPanStart: _startStroke,
              onPanUpdate: _appendStroke,
              onPanEnd: _endStroke,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ToggleButtons(
                isSelected: [_eraser == false, _eraser == true],
                onPressed: (index) => setState(() => _eraser = index == 1),
                children: const [
                  Tooltip(message: 'Pen', child: Icon(Icons.edit)),
                  Tooltip(
                    message: 'Eraser',
                    child: Icon(Icons.cleaning_services),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final color in _colors)
                      _ColorDot(
                        color: color,
                        isSelected: color == _selectedColor && !_eraser,
                        onTap: () => setState(() {
                          _selectedColor = color;
                          _eraser = false;
                        }),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Clear board',
                onPressed: () => widget.onBoardChanged([]),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DrawingBoard extends StatelessWidget {
  final List<_BoardStroke> strokes;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final bool isTransparent;
  final bool isPanMode;
  final TransformationController? transformationController;
  final Size? canvasSize;

  const _DrawingBoard({
    required this.strokes,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.isTransparent = false,
    this.isPanMode = false,
    this.transformationController,
    this.canvasSize,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: transformationController,
      panEnabled: isPanMode,
      scaleEnabled: isPanMode,
      minScale: 0.1,
      maxScale: 10.0,
      constrained: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: isPanMode ? null : onPanStart,
        onPanUpdate: isPanMode ? null : onPanUpdate,
        onPanEnd: isPanMode ? null : onPanEnd,
        child: canvasSize != null 
          ? Container(
              width: canvasSize!.width,
              height: canvasSize!.height,
              color: Colors.transparent, // Capture gestures
              child: CustomPaint(
                painter: _NotebookSketchPainter(strokes, isTransparent: isTransparent),
                size: canvasSize!,
              ),
            )
          : CustomPaint(
              painter: _NotebookSketchPainter(strokes, isTransparent: isTransparent),
              child: const SizedBox.expand(),
            ),
      ),
    );
  }
}

class _NotebookSketchPainter extends CustomPainter {
  final List<_BoardStroke> strokes;
  final bool isTransparent;

  const _NotebookSketchPainter(this.strokes, {this.isTransparent = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isTransparent) {
      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(Offset.zero & size, bgPaint);
      
      final gridPaint = Paint()
        ..color = AppColors.lightBorder
        ..strokeWidth = 1;
      for (var y = 24.0; y < size.height; y += 24) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final inkPaint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, inkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NotebookSketchPainter oldDelegate) =>
      oldDelegate.strokes != strokes || oldDelegate.isTransparent != isTransparent;
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
    );
  }
}

class _BoardStroke {
  final Color color;
  final double width;
  final List<Offset> points;
  final bool isTeacher;

  const _BoardStroke({
    required this.color,
    required this.width,
    required this.points,
    this.isTeacher = false,
  });

  _BoardStroke copyWith({Color? color, double? width, List<Offset>? points, bool? isTeacher}) {
    return _BoardStroke(
      color: color ?? this.color,
      width: width ?? this.width,
      points: points ?? this.points,
      isTeacher: isTeacher ?? this.isTeacher,
    );
  }

  Map<String, dynamic> toJson() => {
    'color': color.toARGB32(),
    'width': width,
    'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    'isTeacher': isTeacher,
  };

  static _BoardStroke fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? [];
    return _BoardStroke(
      color: Color(json['color'] as int? ?? 0xFF1E40AF),
      width: (json['width'] as num? ?? 4).toDouble(),
      points: rawPoints.map((p) {
        final point = Map<String, dynamic>.from(p as Map);
        return Offset(
          (point['x'] as num? ?? 0).toDouble(),
          (point['y'] as num? ?? 0).toDouble(),
        );
      }).toList(),
      isTeacher:
          json['isTeacher'] as bool? ?? json['is_teacher'] as bool? ?? false,
    );
  }
}

String _encodeBoard(List<_BoardStroke> strokes) {
  return jsonEncode({'strokes': strokes.map((s) => s.toJson()).toList()});
}

List<_BoardStroke> _decodeBoard(String raw) {
  if (raw.trim().isEmpty) return [];
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rawStrokes = decoded['strokes'] as List<dynamic>? ?? [];
    return rawStrokes
        .map((s) => _BoardStroke.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();
  } catch (_) {
    return [];
  }
}

class _CodePane extends StatefulWidget {
  final StudyWorkspaceViewModel viewModel;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _CodePane({
    required this.viewModel,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<_CodePane> createState() => _CodePaneState();
}

class _CodePaneState extends State<_CodePane> {
  String _language = 'python';
  bool _isLoadingChallenges = false;
  bool _isRunningChallenge = false;
  List<_CodeChallenge> _challenges = [];
  _CodeChallenge? _selectedChallenge;
  _ChallengeRunResult? _challengeResult;
  bool _isVisualizing = false;
  int _activeTraceIndex = -1;
  List<_CodeTraceStep> _traceSteps = [];

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  @override
  void dispose() {
    _isVisualizing = false;
    super.dispose();
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoadingChallenges = true);
    try {
      final rows = await Supabase.instance.client.rpc(
        'get_lesson_code_challenges',
        params: {'p_lesson_id': widget.viewModel.lesson.id},
      );
      final challenges = (rows as List)
          .whereType<Map>()
          .map(_CodeChallenge.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _challenges = challenges;
        _selectedChallenge = challenges.isEmpty ? null : challenges.first;
        _isLoadingChallenges = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingChallenges = false);
    }
  }

  Future<void> _runSelectedChallenge() async {
    final challenge = _selectedChallenge;
    if (challenge == null) return;
    setState(() {
      _isRunningChallenge = true;
      _challengeResult = null;
    });

    final caseResults = <_ChallengeCaseResult>[];
    for (final testCase in challenge.testCases) {
      try {
        final response = await http
            .post(
              Uri.parse('${AppConfig.effectiveCodeSandboxUrl}/run'),
              headers: AppConfig.codeSandboxHeaders,
              body: jsonEncode({
                'language': _language,
                'code': widget.controller.text,
                'stdin': testCase.stdin,
              }),
            )
            .timeout(const Duration(seconds: 12));
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final stdout = (decoded['stdout'] ?? '').toString().trimRight();
        final stderr = (decoded['stderr'] ?? '').toString().trimRight();
        final expected = testCase.expectedStdout.trimRight();
        caseResults.add(
          _ChallengeCaseResult(
            name: testCase.name,
            passed:
                response.statusCode == 200 &&
                decoded['success'] == true &&
                stdout == expected,
            expected: expected,
            actual: stdout.isEmpty ? stderr : stdout,
          ),
        );
      } catch (e) {
        caseResults.add(
          _ChallengeCaseResult(
            name: testCase.name,
            passed: false,
            expected: testCase.expectedStdout.trimRight(),
            actual: 'Sandbox error: $e',
          ),
        );
      }
    }

    final passed = caseResults.where((item) => item.passed).length;
    final result = _ChallengeRunResult(
      passed: passed,
      total: caseResults.length,
      cases: caseResults,
    );

    try {
      await Supabase.instance.client.rpc(
        'submit_code_challenge_result',
        params: {
          'p_challenge_id': challenge.id,
          'p_language': _language,
          'p_source_code': widget.controller.text,
          'p_passed_cases': passed,
          'p_total_cases': caseResults.length,
        },
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _challengeResult = result;
      _isRunningChallenge = false;
    });
  }

  Future<void> _visualizeCode() async {
    final steps = _buildTraceSteps(widget.controller.text, _language);
    if (steps.isEmpty) {
      setState(() {
        _traceSteps = const [
          _CodeTraceStep(
            lineNumber: 0,
            code: 'No executable lines yet.',
            explanation: 'Write a few lines, then run the visualizer again.',
          ),
        ];
        _activeTraceIndex = 0;
        _isVisualizing = false;
      });
      return;
    }

    setState(() {
      _traceSteps = steps;
      _activeTraceIndex = 0;
      _isVisualizing = true;
    });

    for (var i = 0; i < steps.length; i++) {
      if (!mounted || !_isVisualizing) return;
      setState(() => _activeTraceIndex = i);
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }

    if (!mounted) return;
    setState(() => _isVisualizing = false);
  }

  void _stopVisualization() {
    setState(() => _isVisualizing = false);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: widget.onChanged,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Code Playground',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          initialValue: _language,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Language',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'python',
                              child: Text('Python'),
                            ),
                            DropdownMenuItem(value: 'cpp', child: Text('C++')),
                          ],
                          onChanged: viewModel.isRunningCode
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _language = value);
                                },
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: viewModel.isRunningCode
                            ? null
                            : () => viewModel.runCode(
                                code: widget.controller.text,
                                language: _language,
                              ),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          viewModel.isRunningCode ? 'Running' : 'Run code',
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isVisualizing ? null : _visualizeCode,
                        icon: const Icon(Icons.auto_graph),
                        label: Text(
                          _isVisualizing ? 'Visualizing' : 'Visualize',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: viewModel.isRunningCode
                            ? null
                            : () => viewModel.runCodePreview(
                                widget.controller.text,
                              ),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Run preview'),
                      ),
                      const SizedBox(
                        width: 260,
                        child: Text(
                          'Visualize explains the flow. Run code uses the configured Sandbox Server.',
                        ),
                      ),
                    ],
                  ),
                  if (_traceSteps.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _CodeTracePanel(
                      steps: _traceSteps,
                      activeIndex: _activeTraceIndex,
                      isPlaying: _isVisualizing,
                      onStop: _stopVisualization,
                    ),
                  ],
                  if (viewModel.lastRunResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        viewModel.lastRunResult!.output,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ChallengePanel(
                    isLoading: _isLoadingChallenges,
                    isRunning: _isRunningChallenge,
                    challenges: _challenges,
                    selected: _selectedChallenge,
                    result: _challengeResult,
                    onRefresh: _loadChallenges,
                    onSelected: (challenge) =>
                        setState(() => _selectedChallenge = challenge),
                    onRun: _runSelectedChallenge,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengePanel extends StatelessWidget {
  final bool isLoading;
  final bool isRunning;
  final List<_CodeChallenge> challenges;
  final _CodeChallenge? selected;
  final _ChallengeRunResult? result;
  final VoidCallback onRefresh;
  final ValueChanged<_CodeChallenge> onSelected;
  final VoidCallback onRun;

  const _ChallengePanel({
    required this.isLoading,
    required this.isRunning,
    required this.challenges,
    required this.selected,
    required this.result,
    required this.onRefresh,
    required this.onSelected,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Code Challenges',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh challenges',
                  onPressed: isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (isLoading)
              const LinearProgressIndicator()
            else if (challenges.isEmpty)
              const Text('No code challenges published for this lesson.')
            else ...[
              DropdownButtonFormField<_CodeChallenge>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Challenge'),
                items: challenges
                    .map(
                      (challenge) => DropdownMenuItem(
                        value: challenge,
                        child: Text(
                          challenge.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: isRunning || selected == null
                    ? null
                    : (value) {
                        if (value != null) onSelected(value);
                      },
              ),
              const SizedBox(height: 8),
              Text(selected?.description ?? ''),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: isRunning ? null : onRun,
                icon: isRunning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check),
                label: Text(isRunning ? 'Running tests' : 'Run test cases'),
              ),
              if (result != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Passed ${result!.passed}/${result!.total}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: result!.passed == result!.total
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
                const SizedBox(height: 6),
                ...result!.cases.map(
                  (item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.passed ? Icons.check_circle : Icons.cancel,
                      color: item.passed ? AppColors.success : AppColors.error,
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      item.passed
                          ? 'Output matched.'
                          : 'Expected: ${item.expected} | Actual: ${item.actual}',
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CodeTracePanel extends StatelessWidget {
  final List<_CodeTraceStep> steps;
  final int activeIndex;
  final bool isPlaying;
  final VoidCallback onStop;

  const _CodeTracePanel({
    required this.steps,
    required this.activeIndex,
    required this.isPlaying,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeActiveIndex = activeIndex.clamp(0, steps.length - 1);
    final activeStep = steps[safeActiveIndex];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_graph),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Execution Visualizer',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (isPlaying)
                  IconButton.filledTonal(
                    tooltip: 'Stop',
                    onPressed: onStop,
                    icon: const Icon(Icons.stop),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: steps.isEmpty ? 0 : (safeActiveIndex + 1) / steps.length,
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Container(
                key: ValueKey('${activeStep.lineNumber}-${activeStep.code}'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.studentRole.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.studentRole.withValues(alpha: .28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeStep.lineNumber <= 0
                          ? 'Ready'
                          : 'Line ${activeStep.lineNumber}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      activeStep.code,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    Text(activeStep.explanation),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: steps.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final step = steps[index];
                  final isActive = index == safeActiveIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 180,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.studentRole
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive
                            ? AppColors.studentRole
                            : theme.dividerColor,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.lineNumber <= 0
                              ? 'Ready'
                              : 'Line ${step.lineNumber}',
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          step.code,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeTraceStep {
  final int lineNumber;
  final String code;
  final String explanation;

  const _CodeTraceStep({
    required this.lineNumber,
    required this.code,
    required this.explanation,
  });
}

List<_CodeTraceStep> _buildTraceSteps(String source, String language) {
  final steps = <_CodeTraceStep>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('#') || trimmed.startsWith('//')) continue;

    steps.add(
      _CodeTraceStep(
        lineNumber: i + 1,
        code: trimmed,
        explanation: _explainCodeLine(trimmed, language),
      ),
    );
  }
  return steps;
}

String _explainCodeLine(String line, String language) {
  final normalized = line.toLowerCase();
  if (normalized.startsWith('print') || normalized.startsWith('cout')) {
    return 'Output step: this line sends a value to the console so the student can inspect the result.';
  }
  if (normalized.contains('input(') ||
      normalized.contains('cin') ||
      normalized.contains('scanf')) {
    return 'Input step: the program waits for data before it can continue.';
  }
  if (normalized.startsWith('for ') ||
      normalized.startsWith('for(') ||
      normalized.startsWith('while ') ||
      normalized.startsWith('while(')) {
    return 'Loop step: this block repeats while its condition allows it.';
  }
  if (normalized.startsWith('if ') ||
      normalized.startsWith('if(') ||
      normalized.startsWith('else') ||
      normalized.startsWith('elif')) {
    return 'Decision step: the program chooses a path based on a condition.';
  }
  if (normalized.startsWith('def ') ||
      normalized.contains(' function ') ||
      (language == 'cpp' &&
          normalized.contains('(') &&
          normalized.endsWith('{'))) {
    return 'Function step: this defines reusable logic that runs when called.';
  }
  if (line.contains('=') && !line.contains('==')) {
    return 'Memory step: this stores or updates a value for later lines.';
  }
  if (normalized.startsWith('return')) {
    return 'Return step: this sends a value back to the caller and ends the current function path.';
  }
  return 'Execution step: the interpreter or compiler handles this line as part of the program flow.';
}

class _CodeChallenge {
  final String id;
  final String title;
  final String description;
  final List<_CodeChallengeCase> testCases;

  const _CodeChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.testCases,
  });

  factory _CodeChallenge.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    final cases = (json['test_cases'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(_CodeChallengeCase.fromJson)
        .toList();
    return _CodeChallenge(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Challenge',
      description: json['description']?.toString() ?? '',
      testCases: cases,
    );
  }
}

class _CodeChallengeCase {
  final String name;
  final String stdin;
  final String expectedStdout;

  const _CodeChallengeCase({
    required this.name,
    required this.stdin,
    required this.expectedStdout,
  });

  factory _CodeChallengeCase.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _CodeChallengeCase(
      name: json['name']?.toString() ?? 'Case',
      stdin: json['stdin']?.toString() ?? '',
      expectedStdout: json['expected_stdout']?.toString() ?? '',
    );
  }
}

class _ChallengeRunResult {
  final int passed;
  final int total;
  final List<_ChallengeCaseResult> cases;

  const _ChallengeRunResult({
    required this.passed,
    required this.total,
    required this.cases,
  });
}

class _ChallengeCaseResult {
  final String name;
  final bool passed;
  final String expected;
  final String actual;

  const _ChallengeCaseResult({
    required this.name,
    required this.passed,
    required this.expected,
    required this.actual,
  });
}

class _StickyNoteDialog extends StatefulWidget {
  const _StickyNoteDialog();

  @override
  State<_StickyNoteDialog> createState() => _StickyNoteDialogState();
}

class _StickyNoteDialogState extends State<_StickyNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Note'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Note',
          alignLabelWithHint: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ],
    );
  }
}
