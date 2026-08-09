import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';

class StudyReplayScreen extends StatefulWidget {
  final String? teacherId;

  const StudyReplayScreen({super.key, this.teacherId});

  @override
  State<StudyReplayScreen> createState() => _StudyReplayScreenState();
}

class _StudyReplayScreenState extends State<StudyReplayScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<_ReplaySession> _sessions = [];
  List<_ReplayEvent> _events = [];
  _ReplaySession? _selectedSession;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rows = widget.teacherId == null
          ? await Supabase.instance.client
                .from('study_sessions')
                .select(
                  'id, student_id, lesson_id, started_at, ended_at, duration_seconds, pages_read, students(student_code, profiles(full_name)), lessons(title)',
                )
                .order('started_at', ascending: false)
                .limit(80)
          : await Supabase.instance.client.rpc(
              'get_teacher_study_replay_sessions',
              params: {'p_teacher_id': widget.teacherId},
            );

      final sessions = (rows as List)
          .whereType<Map>()
          .map(_ReplaySession.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _selectedSession = sessions.isEmpty ? null : sessions.first;
        _isLoading = false;
      });
      if (_selectedSession != null) {
        await _loadEvents(_selectedSession!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEvents(_ReplaySession session) async {
    try {
      final rows = await Supabase.instance.client.rpc(
        'get_study_replay_events',
        params: {'p_session_id': session.id},
      );
      if (!mounted) return;
      setState(() {
        _selectedSession = session;
        _events = (rows as List)
            .whereType<Map>()
            .map(_ReplayEvent.fromJson)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'Study Replay',
      subtitle: 'Structured timeline of student study activity.',
      icon: Icons.video_library,
      accentColor: AppColors.teacherRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'Refresh',
          onPressed: _loadSessions,
        ),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: _sessions.isEmpty,
        emptyTitle: 'No replay sessions',
        emptySubtitle: 'Replay data appears after students open lessons.',
        emptyIcon: Icons.video_library,
        onRetry: _loadSessions,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 920;
            final sessionList = _SessionList(
              sessions: _sessions,
              selected: _selectedSession,
              onSelected: _loadEvents,
            );
            final timeline = _ReplayTimeline(
              session: _selectedSession,
              events: _events,
            );
            if (isWide) {
              return Row(
                children: [
                  SizedBox(width: 360, child: sessionList),
                  const VerticalDivider(width: 1),
                  Expanded(child: timeline),
                ],
              );
            }
            return ListView(
              children: [
                SizedBox(height: 300, child: sessionList),
                const SizedBox(height: 12),
                SizedBox(height: 520, child: timeline),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  final List<_ReplaySession> sessions;
  final _ReplaySession? selected;
  final ValueChanged<_ReplaySession> onSelected;

  const _SessionList({
    required this.sessions,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(right: 12),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isSelected = selected?.id == session.id;
        return PortalListCard(
          icon: Icons.play_circle,
          accentColor: isSelected ? AppColors.teacherRole : AppColors.info,
          title: session.studentName,
          subtitle:
              '${session.lessonTitle} | ${session.durationSeconds}s | ${session.pagesRead} pages',
          trailing: [PortalStatusChip(status: session.startedLabel)],
          onTap: () => onSelected(session),
        );
      },
    );
  }
}

class _ReplayTimeline extends StatelessWidget {
  final _ReplaySession? session;
  final List<_ReplayEvent> events;

  const _ReplayTimeline({required this.session, required this.events});

  @override
  Widget build(BuildContext context) {
    final selected = session;
    if (selected == null) {
      return const Center(child: Text('Select a replay session.'));
    }
    if (events.isEmpty) {
      return const Center(child: Text('No events were recorded.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(left: 12),
      itemCount: events.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return PortalHeader(
            eyebrow: 'Replay',
            title: selected.lessonTitle,
            subtitle:
                '${selected.studentName} | ${selected.startedLabel} | ${selected.durationSeconds}s',
            icon: Icons.video_library,
            accentColor: AppColors.teacherRole,
          );
        }
        final event = events[index - 1];
        return PortalListCard(
          icon: event.icon,
          accentColor: event.color,
          title: event.eventType.replaceAll('_', ' '),
          subtitle: '${event.offsetLabel} | ${event.payload}',
          trailing: [PortalStatusChip(status: event.kind)],
        );
      },
    );
  }
}

class _ReplaySession {
  final String id;
  final String studentName;
  final String lessonTitle;
  final int durationSeconds;
  final int pagesRead;
  final DateTime startedAt;

  const _ReplaySession({
    required this.id,
    required this.studentName,
    required this.lessonTitle,
    required this.durationSeconds,
    required this.pagesRead,
    required this.startedAt,
  });

  factory _ReplaySession.fromJson(Map row) {
    final student = _asMap(row['students']);
    final profile = _asMap(student['profiles']);
    final lesson = _asMap(row['lessons']);
    return _ReplaySession(
      id: row['id']?.toString() ?? '',
      studentName:
          profile['full_name']?.toString() ??
          student['student_code']?.toString() ??
          row['student_full_name']?.toString() ??
          'Student',
      lessonTitle:
          lesson['title']?.toString() ??
          row['lesson_title']?.toString() ??
          'Lesson',
      durationSeconds:
          int.tryParse(row['duration_seconds']?.toString() ?? '') ?? 0,
      pagesRead: int.tryParse(row['pages_read']?.toString() ?? '') ?? 0,
      startedAt:
          DateTime.tryParse(row['started_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get startedLabel {
    final month = startedAt.month.toString().padLeft(2, '0');
    final day = startedAt.day.toString().padLeft(2, '0');
    return '${startedAt.year}-$month-$day';
  }
}

class _ReplayEvent {
  final String eventType;
  final int offsetMs;
  final Map<String, dynamic> payload;

  const _ReplayEvent({
    required this.eventType,
    required this.offsetMs,
    required this.payload,
  });

  factory _ReplayEvent.fromJson(Map row) {
    return _ReplayEvent(
      eventType: row['event_type']?.toString() ?? 'event',
      offsetMs: int.tryParse(row['event_offset_ms']?.toString() ?? '') ?? 0,
      payload: _asMap(row['payload']),
    );
  }

  String get kind => eventType.split('_').first;

  String get offsetLabel {
    final seconds = offsetMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  IconData get icon {
    return switch (kind) {
      'page' => Icons.menu_book,
      'pdf' => Icons.picture_as_pdf,
      'board' => Icons.draw,
      'notebook' => Icons.note_alt,
      _ => Icons.timeline,
    };
  }

  Color get color {
    return switch (kind) {
      'page' => AppColors.info,
      'pdf' => AppColors.error,
      'board' => AppColors.success,
      'notebook' => AppColors.warning,
      _ => AppColors.teacherRole,
    };
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}
