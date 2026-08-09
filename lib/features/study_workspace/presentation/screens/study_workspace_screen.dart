import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                                    onNotebookChanged: _queueNotebookSave,
                                    onCodeChanged: _queueCodeSave,
                                  )
                                : TabBarView(
                                    children: [
                                      _PdfPane(viewModel: _viewModel),
                                      _NotebookPane(
                                        controller: _notebookController,
                                        onChanged: _queueNotebookSave,
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
  final ValueChanged<String> onNotebookChanged;
  final ValueChanged<String> onCodeChanged;

  const _WideWorkspace({
    required this.viewModel,
    required this.notebookController,
    required this.codeController,
    required this.onNotebookChanged,
    required this.onCodeChanged,
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
                onChanged: onNotebookChanged,
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
          child: _SignedPdfViewer(
            url: lesson.pdfUrl!,
            initialPage: viewModel.currentPage,
            onPageChanged: viewModel.goToPage,
          ),
        ),
        PositionedDirectional(
          end: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'page_control',
            onPressed: () => viewModel.goToPage(viewModel.currentPage + 1),
            icon: const Icon(Icons.navigate_next),
            label: Text('Page ${viewModel.currentPage}/${lesson.totalPages}'),
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
  final int initialPage;
  final ValueChanged<int> onPageChanged;

  const _SignedPdfViewer({
    required this.url,
    required this.initialPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.picture_as_pdf,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'PDF resource is ready',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Copy the signed resource link and open it in your browser or PDF reader.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SelectableText(url, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    onPageChanged(initialPage);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PDF link copied.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy PDF Link'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotebookPane extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _NotebookPane({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              onChanged: onChanged,
              decoration: const InputDecoration(
                labelText: 'Smart Notebook',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: CustomPaint(painter: _NotebookSketchPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotebookSketchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.lightBorder
      ..strokeWidth = 1;
    for (var y = 24.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final inkPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(24, 82)
      ..cubicTo(90, 20, 120, 140, 190, 70)
      ..cubicTo(240, 20, 280, 118, 340, 76);
    canvas.drawPath(path, inkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
