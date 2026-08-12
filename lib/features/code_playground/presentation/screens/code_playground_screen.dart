import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
      _terminalOutput = 'Running...';
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
      final response = await http.post(
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
      );

      if (mounted) {
        setState(() {
          _isRunning = false;
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
          _terminalOutput = 'Error connecting to execution API:\n$e';
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
                      const Text(
                        'Run',
                        style: TextStyle(
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
                  height: 300,
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
                          const Text(
                            'Terminal Output',
                            style: TextStyle(
                              color: AppColors.darkTextSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
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
                  tooltip: 'Starter code',
                  onPressed: onInsertStarter,
                  icon: const Icon(Icons.post_add, color: Colors.white),
                ),
                IconButton(
                  tooltip: 'Format',
                  onPressed: onFormat,
                  icon: const Icon(Icons.auto_fix_high, color: Colors.white),
                ),
                IconButton(
                  tooltip: 'Clear',
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
