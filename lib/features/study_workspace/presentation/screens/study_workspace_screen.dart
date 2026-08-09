import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../domain/models/study_workspace_models.dart';
import '../../domain/repositories/study_workspace_repository.dart';
import '../viewmodels/study_workspace_viewmodel.dart';

class StudyWorkspaceScreen extends StatefulWidget {
  final StudyLessonSummary lesson;
  final String? studentId;
  final IStudyWorkspaceRepository? repository;

  const StudyWorkspaceScreen({
    super.key,
    required this.lesson,
    this.studentId,
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

  @override
  void initState() {
    super.initState();
    _viewModel = StudyWorkspaceViewModel(
      lesson: widget.lesson,
      studentId: widget.studentId,
      repository: widget.repository,
    );
    _notebookController = TextEditingController();
    _codeController = TextEditingController();
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
    if (_boardStrokes.isEmpty && _viewModel.boardData.isNotEmpty) {
      setState(() => _boardStrokes = _decodeBoard(_viewModel.boardData));
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
      _viewModel.saveBoard(_encodeBoard(strokes));
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
    if (repository == null || studentId == null) return;
    try {
      final cloudRows = await repository.fetchPdfAnnotations(
        studentId: studentId,
        lessonId: widget.lesson.id,
      );
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
    final studentId = widget.studentId;
    if (repository == null || studentId == null) return;
    try {
      await repository.savePdfAnnotations(
        studentId: studentId,
        lessonId: widget.lesson.id,
        annotations: annotations
            .map((annotation) => annotation.toJson())
            .toList(),
      );
    } catch (_) {}
  }

  String get _pdfAnnotationKey =>
      'study_workspace_pdf_annotations_${widget.lesson.id}';

  Future<void> _addStickyNote() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Note on page ${_viewModel.currentPage}'),
        content: TextField(
          controller: controller,
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
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty) return;
    await _savePdfAnnotations([
      ..._pdfAnnotations,
      _PdfAnnotation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        page: _viewModel.currentPage,
        type: _PdfAnnotationType.note,
        text: text,
        createdAt: DateTime.now(),
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
      ),
    ]);
    _recordReplayEvent('pdf_bookmark_added', {'page': page});
  }

  Future<void> _deletePdfAnnotation(String id) async {
    await _savePdfAnnotations(
      _pdfAnnotations.where((annotation) => annotation.id != id).toList(),
    );
    _recordReplayEvent('pdf_annotation_deleted', {'id': id});
  }

  Future<void> _goToPage(int delta) async {
    await _viewModel.goToPage(_viewModel.currentPage + delta);
    _visitedPages.add(_viewModel.currentPage);
    _recordReplayEvent('page_changed', {'page': _viewModel.currentPage});
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.lesson.title),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 16),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _viewModel.isSaving
                        ? const SizedBox(
                            key: ValueKey('saving'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            key: ValueKey('saved'),
                            Icons.cloud_done_outlined,
                          ),
                  ),
                ),
              ),
            ],
          ),
          body: !_viewModel.isLoaded
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;
                    return DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          _WorkspaceHeader(lesson: widget.lesson),
                          const TabBar(
                            tabs: [
                              Tab(
                                icon: Icon(Icons.picture_as_pdf),
                                text: 'PDF',
                              ),
                              Tab(
                                icon: Icon(Icons.draw_outlined),
                                text: 'Notebook',
                              ),
                              Tab(icon: Icon(Icons.code), text: 'Code'),
                            ],
                          ),
                          Expanded(
                            child: isWide
                                ? _WideWorkspace(
                                    viewModel: _viewModel,
                                    notebookController: _notebookController,
                                    codeController: _codeController,
                                    boardStrokes: _boardStrokes,
                                    pdfAnnotations: _pdfAnnotations,
                                    onNotebookChanged: _queueNotebookSave,
                                    onCodeChanged: _queueCodeSave,
                                    onBoardChanged: _queueBoardSave,
                                    onPdfNote: _addStickyNote,
                                    onPdfHighlight: _addHighlight,
                                    onPdfBookmark: _toggleBookmark,
                                    onPdfAnnotationDelete: _deletePdfAnnotation,
                                    onPreviousPdfPage: () => _goToPage(-1),
                                    onNextPdfPage: () => _goToPage(1),
                                  )
                                : TabBarView(
                                    children: [
                                      _PdfPane(
                                        viewModel: _viewModel,
                                        annotations: _pdfAnnotations,
                                        onAddNote: _addStickyNote,
                                        onAddHighlight: _addHighlight,
                                        onToggleBookmark: _toggleBookmark,
                                        onDeleteAnnotation:
                                            _deletePdfAnnotation,
                                        onPreviousPage: () => _goToPage(-1),
                                        onNextPage: () => _goToPage(1),
                                      ),
                                      _NotebookPane(
                                        controller: _notebookController,
                                        strokes: _boardStrokes,
                                        onChanged: _queueNotebookSave,
                                        onBoardChanged: _queueBoardSave,
                                      ),
                                      _CodePane(
                                        viewModel: _viewModel,
                                        controller: _codeController,
                                        onChanged: _queueCodeSave,
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  final StudyLessonSummary lesson;

  const _WorkspaceHeader({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: .4)),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _HeaderChip(icon: Icons.route, label: lesson.pathName),
          _HeaderChip(icon: Icons.menu_book_outlined, label: lesson.unitName),
          _HeaderChip(
            icon: Icons.timer_outlined,
            label: '${lesson.estimatedMinutes} min',
          ),
          _HeaderChip(icon: Icons.auto_awesome, label: '${lesson.xp} XP'),
          SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              value: lesson.progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Text('${lesson.progressPercentage}% complete'),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _WideWorkspace extends StatelessWidget {
  final StudyWorkspaceViewModel viewModel;
  final TextEditingController notebookController;
  final TextEditingController codeController;
  final List<_BoardStroke> boardStrokes;
  final List<_PdfAnnotation> pdfAnnotations;
  final ValueChanged<String> onNotebookChanged;
  final ValueChanged<String> onCodeChanged;
  final ValueChanged<List<_BoardStroke>> onBoardChanged;
  final VoidCallback onPdfNote;
  final VoidCallback onPdfHighlight;
  final VoidCallback onPdfBookmark;
  final ValueChanged<String> onPdfAnnotationDelete;
  final VoidCallback onPreviousPdfPage;
  final VoidCallback onNextPdfPage;

  const _WideWorkspace({
    required this.viewModel,
    required this.notebookController,
    required this.codeController,
    required this.boardStrokes,
    required this.pdfAnnotations,
    required this.onNotebookChanged,
    required this.onCodeChanged,
    required this.onBoardChanged,
    required this.onPdfNote,
    required this.onPdfHighlight,
    required this.onPdfBookmark,
    required this.onPdfAnnotationDelete,
    required this.onPreviousPdfPage,
    required this.onNextPdfPage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: _PdfPane(
            viewModel: viewModel,
            annotations: pdfAnnotations,
            onAddNote: onPdfNote,
            onAddHighlight: onPdfHighlight,
            onToggleBookmark: onPdfBookmark,
            onDeleteAnnotation: onPdfAnnotationDelete,
            onPreviousPage: onPreviousPdfPage,
            onNextPage: onNextPdfPage,
          ),
        ),
        VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
        Expanded(
          flex: 4,
          child: TabBarView(
            children: [
              _PdfPane(
                viewModel: viewModel,
                annotations: pdfAnnotations,
                onAddNote: onPdfNote,
                onAddHighlight: onPdfHighlight,
                onToggleBookmark: onPdfBookmark,
                onDeleteAnnotation: onPdfAnnotationDelete,
                onPreviousPage: onPreviousPdfPage,
                onNextPage: onNextPdfPage,
              ),
              _NotebookPane(
                controller: notebookController,
                strokes: boardStrokes,
                onChanged: onNotebookChanged,
                onBoardChanged: onBoardChanged,
              ),
              _CodePane(
                viewModel: viewModel,
                controller: codeController,
                onChanged: onCodeChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PdfPane extends StatelessWidget {
  final StudyWorkspaceViewModel viewModel;
  final List<_PdfAnnotation> annotations;
  final VoidCallback onAddNote;
  final VoidCallback onAddHighlight;
  final VoidCallback onToggleBookmark;
  final ValueChanged<String> onDeleteAnnotation;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;

  const _PdfPane({
    required this.viewModel,
    required this.annotations,
    required this.onAddNote,
    required this.onAddHighlight,
    required this.onToggleBookmark,
    required this.onDeleteAnnotation,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    final lesson = viewModel.lesson;
    if (lesson.pdfUrl == null) {
      return _MissingPdfState(lesson: lesson);
    }

    final pageAnnotations = annotations
        .where((annotation) => annotation.page == viewModel.currentPage)
        .toList();
    final hasBookmark = pageAnnotations.any(
      (annotation) => annotation.type == _PdfAnnotationType.bookmark,
    );
    final highlights = pageAnnotations
        .where((annotation) => annotation.type == _PdfAnnotationType.highlight)
        .toList();

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: _SignedPdfViewer(
            url: lesson.pdfUrl!,
            pageNumber: viewModel.currentPage,
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
        PositionedDirectional(
          start: 16,
          top: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: .9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.picture_as_pdf, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text('Page ${viewModel.currentPage}/${lesson.totalPages}'),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Previous page',
                    visualDensity: VisualDensity.compact,
                    onPressed: viewModel.currentPage <= 1
                        ? null
                        : onPreviousPage,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    visualDensity: VisualDensity.compact,
                    onPressed: viewModel.currentPage >= lesson.totalPages
                        ? null
                        : onNextPage,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ),
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
                  onPressed: onToggleBookmark,
                  icon: Icon(
                    hasBookmark ? Icons.bookmark : Icons.bookmark_border,
                    color: hasBookmark ? AppColors.warning : null,
                  ),
                ),
                IconButton(
                  tooltip: 'Highlight',
                  onPressed: onAddHighlight,
                  icon: const Icon(Icons.format_color_fill),
                ),
                IconButton(
                  tooltip: 'Sticky note',
                  onPressed: onAddNote,
                  icon: const Icon(Icons.sticky_note_2_outlined),
                ),
              ],
            ),
          ),
        ),
        PositionedDirectional(
          start: 16,
          end: 16,
          bottom: 16,
          child: _PdfAnnotationTray(
            annotations: pageAnnotations,
            onDelete: onDeleteAnnotation,
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

class _PdfAnnotationTray extends StatelessWidget {
  final List<_PdfAnnotation> annotations;
  final ValueChanged<String> onDelete;

  const _PdfAnnotationTray({required this.annotations, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final visible = annotations
        .where((annotation) => annotation.type != _PdfAnnotationType.bookmark)
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

enum _PdfAnnotationType { bookmark, highlight, note }

class _PdfAnnotation {
  final String id;
  final int page;
  final _PdfAnnotationType type;
  final String text;
  final DateTime createdAt;

  const _PdfAnnotation({
    required this.id,
    required this.page,
    required this.type,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'page': page,
    'type': type.name,
    'text': text,
    'created_at': createdAt.toIso8601String(),
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
    );
  }

  String get dateLabel {
    final month = createdAt.month.toString().padLeft(2, '0');
    final day = createdAt.day.toString().padLeft(2, '0');
    return '${createdAt.year}-$month-$day';
  }
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
  final int pageNumber;

  const _SignedPdfViewer({required this.url, required this.pageNumber});

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
        child: PdfViewer.uri(
          Uri.parse(widget.url),
          controller: _controller,
          initialPageNumber: widget.pageNumber,
          params: PdfViewerParams(
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
                      const Text('Loading PDF...'),
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
                        'PDF failed to load',
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

  const _DrawingBoard({
    required this.strokes,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: GestureDetector(
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          child: CustomPaint(
            painter: _NotebookSketchPainter(strokes),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _NotebookSketchPainter extends CustomPainter {
  final List<_BoardStroke> strokes;

  const _NotebookSketchPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.lightBorder
      ..strokeWidth = 1;
    for (var y = 24.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
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
      oldDelegate.strokes != strokes;
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

  const _BoardStroke({
    required this.color,
    required this.width,
    required this.points,
  });

  _BoardStroke copyWith({List<Offset>? points}) {
    return _BoardStroke(
      color: color,
      width: width,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() => {
    'color': color.toARGB32(),
    'width': width,
    'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
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

  @override
  void initState() {
    super.initState();
    _loadChallenges();
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
              headers: const {'Content-Type': 'application/json'},
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
                          'Runs through the configured Sandbox Server.',
                        ),
                      ),
                    ],
                  ),
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
