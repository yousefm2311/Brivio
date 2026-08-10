import re

file_path = r'd:\flutter_application_1\lib\features\study_workspace\presentation\screens\study_workspace_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. State Variables
old_state = '''  List<_PdfAnnotation> _pdfAnnotations = [];
  bool _pdfAnnotationsLoaded = false;
  String? _studySessionId;
  DateTime? _studySessionStartedAt;
  final Set<int> _visitedPages = {};

  @override'''
new_state = '''  List<_PdfAnnotation> _pdfAnnotations = [];
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

  @override'''
content = content.replace(old_state, new_state)

# 2. Build Method
build_start = '  @override\n  Widget build(BuildContext context) {'
build_pattern = re.compile(re.escape(build_start) + r'.*?' + r'\s+  \}\n\}', re.DOTALL)
new_build = '''  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    
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

        return Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: [
              if (hasPdf)
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

              Positioned.fill(
                child: _DrawingBoard(
                  strokes: _activeStroke == null ? _boardStrokes : [..._boardStrokes, _activeStroke!],
                  onPanStart: _startStroke,
                  onPanUpdate: _appendStroke,
                  onPanEnd: _endStroke,
                  isTransparent: hasPdf,
                ),
              ),

              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                child: _FloatingHeaderPill(lesson: widget.lesson, isSaving: _viewModel.isSaving),
              ),

              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                right: 24,
                child: _FloatingToolMenu(
                  isOpen: _isFabMenuOpen,
                  onToggle: () => setState(() => _isFabMenuOpen = !_isFabMenuOpen),
                  selectedColor: _selectedColor,
                  eraser: _eraser,
                  onColorSelected: (c) => setState(() { _selectedColor = c; _eraser = false; }),
                  onToggleEraser: () => setState(() => _eraser = !_eraser),
                  onClear: _clearBoard,
                  hasPdf: hasPdf,
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
}'''
content = build_pattern.sub(new_build, content, count=1)

# 3. Replace WorkspaceHeader, HeaderChip, WideWorkspace
header_start = 'class _WorkspaceHeader extends StatelessWidget {'
header_pattern = re.compile(re.escape(header_start) + r'.*?' + r'\s+  \}\n\}\n\nclass _PdfPane', re.DOTALL)
new_headers = '''class _FloatingHeaderPill extends StatelessWidget {
  final StudyLessonSummary lesson;
  final bool isSaving;

  const _FloatingHeaderPill({required this.lesson, required this.isSaving});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(30),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BackButton(),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lesson.title,
                style: AppTypography.labelLarge(
                  isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 12, color: AppColors.info),
                  const SizedBox(width: 4),
                  Text(
                    '${lesson.estimatedMinutes} min',
                    style: const TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: lesson.progress,
                        minHeight: 4,
                        backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isSaving
                        ? const SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.success),
                  ),
                ],
              ),
            ],
          ),
        ],
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
                  icon: Icon(Icons.cleaning_services_rounded, color: eraser ? AppColors.primary : null),
                  tooltip: 'Eraser',
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
          backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.primary,
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

class _PdfPane'''
content = header_pattern.sub(new_headers, content, count=1)


# 4. _DrawingBoard class replacement
board_start = 'class _DrawingBoard extends StatelessWidget {'
board_end = '      oldDelegate.strokes != strokes;\n}'
board_pattern = re.compile(re.escape(board_start) + r'.*?' + re.escape(board_end), re.DOTALL)
new_board = '''class _DrawingBoard extends StatelessWidget {
  final List<_BoardStroke> strokes;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final bool isTransparent;

  const _DrawingBoard({
    required this.strokes,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.isTransparent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: CustomPaint(
        painter: _NotebookSketchPainter(strokes, isTransparent: isTransparent),
        child: const SizedBox.expand(),
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
}'''
content = board_pattern.sub(new_board, content, count=1)


# 5. Remove Pagination from _PdfPane
pagination_start = '        PositionedDirectional(\n          start: 16,\n          top: 16,\n          child: DecoratedBox('
pagination_pattern = re.compile(re.escape(pagination_start) + r'.*?' + r'\s+\]\,\n\s+\),\n\s+\),\n\s+\),\n\s+\),', re.DOTALL)
content = pagination_pattern.sub('        // Pagination moved to Floating UI', content, count=1)

# 6. Modify Draw mode button in _PdfPane
draw_mode_target = '''                IconButton(
                  tooltip: _drawMode ? 'Stop drawing' : 'Draw on PDF',
                  onPressed: () => setState(() => _drawMode = !_drawMode),
                  icon: Icon(
                    _drawMode ? Icons.gesture : Icons.gesture_outlined,
                    color: _drawMode ? AppColors.info : null,
                  ),
                ),'''
content = content.replace(draw_mode_target, '')


with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
