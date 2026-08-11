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
            child: Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _codeController,
                focusNode: _codeFocus,
                maxLines: null,
                expands: true,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: AppColors.darkTextPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '// Write your code here...',
                  hintStyle: TextStyle(
                    color: AppColors.darkTextPlaceholder,
                    fontFamily: 'monospace',
                  ),
                ),
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
