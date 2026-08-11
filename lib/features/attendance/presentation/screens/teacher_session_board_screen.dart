import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../attendance/domain/models/attendance_models.dart';

class TeacherSessionBoardScreen extends StatefulWidget {
  final String teacherId;
  final ClassSession session;

  const TeacherSessionBoardScreen({
    super.key,
    required this.teacherId,
    required this.session,
  });

  @override
  State<TeacherSessionBoardScreen> createState() =>
      _TeacherSessionBoardScreenState();
}

class _TeacherSessionBoardScreenState extends State<TeacherSessionBoardScreen> {
  static const _colors = [
    Color(0xFF111827),
    Color(0xFF1E40AF),
    Color(0xFFDC2626),
    Color(0xFF16A34A),
    Color(0xFFEAB308),
  ];

  final List<_BoardStroke> _strokes = [];
  _BoardStroke? _activeStroke;
  Color _selectedColor = _colors.first;
  bool _eraser = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPublished = false;

  @override
  void initState() {
    super.initState();
    _loadBoard();
  }

  Future<void> _loadBoard() async {
    setState(() => _isLoading = true);
    try {
      final row = await Supabase.instance.client
          .from('class_session_boards')
          .select()
          .eq('class_session_id', widget.session.id)
          .maybeSingle();
      if (!mounted) return;
      if (row != null) {
        final geometry = Map<String, dynamic>.from(
          row['board_data'] as Map? ?? {},
        );
        setState(() {
          _isPublished = row['is_published'] as bool? ?? false;
          _strokes
            ..clear()
            ..addAll(_decodeBoard(jsonEncode(geometry)));
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBoard({bool? publish}) async {
    setState(() => _isSaving = true);
    try {
      final payload = {
        'class_session_id': widget.session.id,
        'group_id': widget.session.groupId,
        'teacher_id': widget.teacherId,
        'board_data': jsonDecode(_encodeBoard(_strokes)),
        'is_published': publish ?? _isPublished,
        'updated_at': DateTime.now().toIso8601String(),
      };
      final row = await Supabase.instance.client
          .from('class_session_boards')
          .upsert(payload, onConflict: 'class_session_id')
          .select()
          .single();
      if (!mounted) return;
      setState(() {
        _isPublished = row['is_published'] as bool? ?? false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Board saved.'))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _startStroke(DragStartDetails details) {
    setState(() {
      _activeStroke = _BoardStroke(
        color: _eraser ? Colors.white : _selectedColor,
        width: _eraser ? 22 : 4,
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
    if (stroke != null && stroke.points.length > 1) {
      setState(() => _strokes.add(stroke));
    }
    setState(() => _activeStroke = null);
  }

  @override
  Widget build(BuildContext context) {
    final visibleStrokes = _activeStroke == null
        ? _strokes
        : [..._strokes, _activeStroke!];
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Session Board')),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            tooltip: context.tr('Save'),
            onPressed: _isSaving ? null : _saveBoard,
            icon: const Icon(Icons.save),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: Size.zero),
              onPressed: _isSaving ? null : () => _saveBoard(publish: true),
              icon: const Icon(Icons.publish, size: 18),
              label: Text(context.tr(_isPublished ? 'Published' : 'Publish')),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Row(
                    children: [
                      ToggleButtons(
                        isSelected: [_eraser == false, _eraser == true],
                        onPressed: (index) =>
                            setState(() => _eraser = index == 1),
                        children: [
                          Tooltip(
                            message: context.tr('Pen'),
                            child: const Icon(Icons.edit),
                          ),
                          Tooltip(
                            message: context.tr('Eraser'),
                            child: const Icon(Icons.cleaning_services),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final color in _colors)
                              _ColorDot(
                                color: color,
                                isSelected: !_eraser && color == _selectedColor,
                                onTap: () => setState(() {
                                  _selectedColor = color;
                                  _eraser = false;
                                }),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('Clear'),
                        onPressed: () => setState(_strokes.clear),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _DrawingBoard(
                      strokes: visibleStrokes,
                      onPanStart: _startStroke,
                      onPanUpdate: _appendStroke,
                      onPanEnd: _endStroke,
                    ),
                  ),
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
            painter: _BoardPainter(strokes),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final List<_BoardStroke> strokes;

  const _BoardPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (var y = 28.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
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
  bool shouldRepaint(covariant _BoardPainter oldDelegate) =>
      oldDelegate.strokes != strokes;
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
      color: Color(json['color'] as int? ?? 0xFF111827),
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
        width: 30,
        height: 30,
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
