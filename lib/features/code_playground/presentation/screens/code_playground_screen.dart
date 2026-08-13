import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../core/localization/app_localizations.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';

class CodePlaygroundScreen extends StatefulWidget {
  const CodePlaygroundScreen({super.key});

  @override
  State<CodePlaygroundScreen> createState() => _CodePlaygroundScreenState();
}

class _CodePlaygroundScreenState extends State<CodePlaygroundScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  String _selectedLanguage = 'Dart';
  final List<String> _languages = ['Dart', 'Python', 'JS', 'C++'];
  bool _isRunning = false;
  bool _isTerminalExpanded = false;
  String _terminalOutput = '';
  String _runStage = '';
  _SortVisualization? _sortVisualization;
  double _fontSize = 15;

  void _runCode() async {
    final code = _codeController.text;
    if (code.trim().isEmpty) {
      setState(() {
        _isTerminalExpanded = true;
        _terminalOutput = 'Error: Code is empty.';
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _isTerminalExpanded = true;
      _runStage = 'Preparing sandbox';
      _terminalOutput = 'Preparing sandbox...';
      _sortVisualization = _SortVisualization.fromCode(code);
    });

    String compilerId;
    switch (_selectedLanguage) {
      case 'Dart':
        compilerId = 'dart373';
        break;
      case 'Python':
        compilerId = 'python311';
        break;
      case 'JS':
        compilerId = 'v8113';
        break;
      case 'C++':
        compilerId = 'g132';
        break;
      default:
        compilerId = 'python311';
    }

    try {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (mounted) {
        setState(() => _runStage = 'Compiling');
      }
      final response = await http
          .post(
            Uri.parse('https://godbolt.org/api/compiler/$compilerId/compile'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              "source": code,
              "compiler": compilerId,
              "options": {
                "userArguments": "",
                "executeParameters": {"args": [], "stdin": ""},
                "compilerOptions": {"executorRequest": true},
                "filters": {"execute": true},
                "tools": [],
                "libraries": [],
              },
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (mounted) {
        setState(() {
          _isRunning = false;
          _runStage = 'Finished';
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            String output = '';

            if (data['stdout'] != null) {
              for (var line in data['stdout']) {
                output += (line['text'] ?? '') + '\n';
              }
            }
            if (data['stderr'] != null) {
              for (var line in data['stderr']) {
                output += (line['text'] ?? '') + '\n';
              }
            }
            if (data['buildResult'] != null &&
                data['buildResult']['stderr'] != null) {
              for (var line in data['buildResult']['stderr']) {
                final text = line['text'] ?? '';
                if (text.isNotEmpty &&
                    !text.startsWith('<Compilation failed>')) {
                  output += text + '\n';
                }
              }
            }

            _terminalOutput = output.trim().isEmpty
                ? 'Program finished with no output.'
                : output.trim();
          } else {
            _terminalOutput =
                'Execution failed. Server responded with status code ${response.statusCode}.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _runStage = 'Stopped';
          _terminalOutput = e is TimeoutException
              ? 'Execution timed out after 20 seconds. Try smaller input or run again.'
              : 'Error connecting to execution API:\n$e';
        });
      }
    }
  }

  void _insertStarter() {
    final snippet = switch (_selectedLanguage) {
      'Dart' => 'void main() {\n  print("Hello Dart");\n}\n',
      'Python' => 'print("Hello Python")\n',
      'JS' => 'console.log("Hello JavaScript");\n',
      'C++' =>
        '#include <iostream>\nusing namespace std;\n\nint main() {\n  cout << "Hello C++" << endl;\n  return 0;\n}\n',
      _ => '',
    };
    final selection = _codeController.selection;
    final text = _codeController.text;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    _codeController.value = TextEditingValue(
      text: text.replaceRange(start, end, snippet),
      selection: TextSelection.collapsed(offset: start + snippet.length),
    );
  }

  void _formatCode() {
    var indent = 0;
    final formatted = <String>[];
    for (final raw in _codeController.text.split('\n')) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        formatted.add('');
        continue;
      }
      if (trimmed.startsWith('}') || trimmed.startsWith(')')) {
        indent = (indent - 1).clamp(0, 99);
      }
      formatted.add('${'  ' * indent}$trimmed');
      if (trimmed.endsWith('{') || trimmed.endsWith(':')) indent++;
    }
    final next = formatted.join('\n');
    _codeController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.glassLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedLanguage,
              dropdownColor: AppColors.darkSurface,
              style: const TextStyle(
                color: AppColors.darkTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.darkTextPrimary,
              ),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedLanguage = newValue;
                  });
                }
              },
              items: _languages.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: InkWell(
                onTap: _isRunning ? null : _runCode,
                borderRadius: BorderRadius.circular(20),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.primarySubtle,
                  borderColor: AppColors.primary,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isRunning)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      else
                        const Icon(
                          Icons.play_arrow,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('Run'),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _HomeCodeEditor(
                controller: _codeController,
                focusNode: _codeFocus,
                language: _selectedLanguage,
                fontSize: _fontSize,
                onInsertStarter: _insertStarter,
                onFormat: _formatCode,
                onClear: () => _codeController.clear(),
                onFontSizeChanged: (value) => setState(() => _fontSize = value),
              ),
            ),
          ),
          if (_isTerminalExpanded)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy > 10) {
                    setState(() {
                      _isTerminalExpanded = false;
                    });
                  }
                },
                child: GlassCard(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  color: AppColors.darkSurface.withValues(alpha: 0.85),
                  height: _sortVisualization == null ? 320 : 430,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.darkTextPlaceholder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                context.tr('Terminal Output'),
                                style: const TextStyle(
                                  color: AppColors.darkTextSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              if (_runStage.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                _RunStagePill(
                                  label: _runStage,
                                  isRunning: _isRunning,
                                ),
                              ],
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.darkTextSecondary,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _isTerminalExpanded = false;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_sortVisualization != null) ...[
                        SizedBox(
                          height: 122,
                          child: _SortVisualizer(
                            visualization: _sortVisualization!,
                            isRunning: _isRunning,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _terminalOutput,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: AppColors.success,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RunStagePill extends StatelessWidget {
  final String label;
  final bool isRunning;

  const _RunStagePill({required this.label, required this.isRunning});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isRunning ? AppColors.warning : AppColors.success).withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (isRunning ? AppColors.warning : AppColors.success).withValues(
            alpha: 0.28,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRunning)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (isRunning) const SizedBox(width: 6),
          Text(
            context.tr(label),
            style: TextStyle(
              color: isRunning ? AppColors.warning : AppColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SortVisualizer extends StatefulWidget {
  final _SortVisualization visualization;
  final bool isRunning;

  const _SortVisualizer({required this.visualization, required this.isRunning});

  @override
  State<_SortVisualizer> createState() => _SortVisualizerState();
}

class _SortVisualizerState extends State<_SortVisualizer> {
  Timer? _timer;
  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant _SortVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visualization != widget.visualization ||
        oldWidget.isRunning != widget.isRunning) {
      _timer?.cancel();
      _stepIndex = 0;
      _start();
    }
  }

  void _start() {
    if (!widget.isRunning || widget.visualization.steps.length <= 1) return;
    _timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) return;
      setState(() {
        _stepIndex = (_stepIndex + 1) % widget.visualization.steps.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget
        .visualization
        .steps[_stepIndex.clamp(0, widget.visualization.steps.length - 1)];
    final maxValue = step.values.fold<int>(1, (max, v) => v > max ? v : max);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF243044)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_graph,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.darkTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < step.values.length; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        height: 24 + (step.values[i] / maxValue) * 54,
                        decoration: BoxDecoration(
                          color: step.highlighted.contains(i)
                              ? AppColors.warning
                              : AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          '${step.values[i]}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    if (i < step.values.length - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortVisualization {
  final List<_SortStep> steps;

  const _SortVisualization(this.steps);

  static _SortVisualization? fromCode(String code) {
    if (!code.toLowerCase().contains('sort')) return null;
    final match = RegExp(r'\[([0-9,\s-]+)\]').firstMatch(code);
    if (match == null) return null;
    final values = match
        .group(1)!
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .where((value) => value >= 0)
        .take(10)
        .toList();
    if (values.length < 2) return null;

    final steps = <_SortStep>[
      _SortStep(List<int>.from(values), const {}, 'Visualizer: initial list'),
    ];
    final working = List<int>.from(values);
    for (var i = 0; i < working.length; i++) {
      for (var j = 0; j < working.length - i - 1; j++) {
        steps.add(
          _SortStep(List<int>.from(working), {
            j,
            j + 1,
          }, 'Compare ${working[j]} and ${working[j + 1]}'),
        );
        if (working[j] > working[j + 1]) {
          final temp = working[j];
          working[j] = working[j + 1];
          working[j + 1] = temp;
          steps.add(
            _SortStep(List<int>.from(working), {
              j,
              j + 1,
            }, 'Swap into ascending order'),
          );
        }
      }
    }
    steps.add(_SortStep(List<int>.from(working), const {}, 'Sorted result'));
    return _SortVisualization(steps);
  }
}

class _SortStep {
  final List<int> values;
  final Set<int> highlighted;
  final String message;

  const _SortStep(this.values, this.highlighted, this.message);
}

class _HomeCodeEditor extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String language;
  final double fontSize;
  final VoidCallback onInsertStarter;
  final VoidCallback onFormat;
  final VoidCallback onClear;
  final ValueChanged<double> onFontSizeChanged;

  const _HomeCodeEditor({
    required this.controller,
    required this.focusNode,
    required this.language,
    required this.fontSize,
    required this.onInsertStarter,
    required this.onFormat,
    required this.onClear,
    required this.onFontSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF243044)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.terminal, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  language,
                  style: const TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: context.tr('Starter code'),
                  onPressed: onInsertStarter,
                  icon: const Icon(Icons.post_add, color: Colors.white),
                ),
                IconButton(
                  tooltip: context.tr('Format'),
                  onPressed: onFormat,
                  icon: const Icon(Icons.auto_fix_high, color: Colors.white),
                ),
                IconButton(
                  tooltip: context.tr('Clear'),
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                SizedBox(
                  width: 110,
                  child: Slider(
                    min: 12,
                    max: 20,
                    divisions: 4,
                    value: fontSize,
                    onChanged: onFontSizeChanged,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF243044)),
          Expanded(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final lineCount = controller.text
                    .split('\n')
                    .length
                    .clamp(1, 9999);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 52,
                      color: const Color(0xFF111827),
                      padding: const EdgeInsets.only(top: 14, right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 1; i <= lineCount; i++)
                            SizedBox(
                              height: fontSize * 1.5,
                              child: Text(
                                '$i',
                                style: TextStyle(
                                  color: const Color(0xFF64748B),
                                  fontFamily: 'monospace',
                                  fontSize: fontSize - 1,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: AppColors.darkTextPrimary,
                          fontSize: fontSize,
                          height: 1.5,
                        ),
                        cursorColor: AppColors.primary,
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          contentPadding: EdgeInsets.all(14),
                          border: InputBorder.none,
                          hintText: '// Write your code here...',
                          hintStyle: TextStyle(
                            color: AppColors.darkTextPlaceholder,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
