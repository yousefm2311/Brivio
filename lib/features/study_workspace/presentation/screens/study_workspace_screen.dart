import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

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
  }

  void _queueNotebookSave(String value) {
    _notebookDebounce?.cancel();
    _notebookDebounce = Timer(const Duration(milliseconds: 450), () {
      _viewModel.saveNotebook(value);
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
    });
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
                                    onNotebookChanged: _queueNotebookSave,
                                    onCodeChanged: _queueCodeSave,
                                    onBoardChanged: _queueBoardSave,
                                  )
                                : TabBarView(
                                    children: [
                                      _PdfPane(viewModel: _viewModel),
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
  final ValueChanged<String> onNotebookChanged;
  final ValueChanged<String> onCodeChanged;
  final ValueChanged<List<_BoardStroke>> onBoardChanged;

  const _WideWorkspace({
    required this.viewModel,
    required this.notebookController,
    required this.codeController,
    required this.boardStrokes,
    required this.onNotebookChanged,
    required this.onCodeChanged,
    required this.onBoardChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 6, child: _PdfPane(viewModel: viewModel)),
        VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
        Expanded(
          flex: 4,
          child: TabBarView(
            children: [
              _PdfPane(viewModel: viewModel),
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

  const _PdfPane({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final lesson = viewModel.lesson;
    if (lesson.pdfUrl == null) {
      return _MissingPdfState(lesson: lesson);
    }

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: _SignedPdfViewer(url: lesson.pdfUrl!),
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
                ],
              ),
            ),
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

class _SignedPdfViewer extends StatelessWidget {
  final String url;

  const _SignedPdfViewer({required this.url});

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
          Uri.parse(url),
          params: PdfViewerParams(
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
          Row(
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

class _CodePane extends StatelessWidget {
  final StudyWorkspaceViewModel viewModel;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _CodePane({
    required this.viewModel,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: onChanged,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Code Playground',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: viewModel.runCodePreview,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run preview'),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Real execution will connect to Sandbox Server.'),
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
        ],
      ),
    );
  }
}
