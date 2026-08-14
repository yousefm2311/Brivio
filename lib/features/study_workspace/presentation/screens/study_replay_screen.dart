import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/widgets/portal_components.dart';

class StudyReplayScreen extends StatefulWidget {
  final String? teacherId;

  const StudyReplayScreen({super.key, this.teacherId});

  @override
  State<StudyReplayScreen> createState() => _StudyReplayScreenState();
}

class _StudyReplayScreenState extends State<StudyReplayScreen> {
  Timer? _playbackTimer;
  bool _isLoading = false;
  bool _isPlaying = false;
  String? _errorMessage;
  List<_ReplaySession> _sessions = [];
  List<_ReplayEvent> _events = [];
  _ReplaySession? _selectedSession;
  int _playbackMs = 0;

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

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
        _playbackMs = 0;
        _isPlaying = false;
      });
      _playbackTimer?.cancel();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    }
  }

  void _togglePlayback() {
    if (_events.isEmpty) return;
    if (_isPlaying) {
      _playbackTimer?.cancel();
      setState(() => _isPlaying = false);
      return;
    }
    setState(() => _isPlaying = true);
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!mounted) return;
      final maxMs = _events.isEmpty ? 0 : _events.last.offsetMs;
      setState(() {
        _playbackMs = (_playbackMs + 1000).clamp(0, maxMs);
        if (_playbackMs >= maxMs) {
          _isPlaying = false;
          _playbackTimer?.cancel();
        }
      });
    });
  }

  void _seekPlayback(double value) {
    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _playbackMs = value.round();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: _sessions.isEmpty,
        emptyTitle: context.tr('No replay sessions'),
        emptySubtitle: context.tr(
          'Replay data appears after students open lessons.',
        ),
        emptyIcon: Icons.video_library,
        onRetry: _loadSessions,
        child: RefreshIndicator(
          onRefresh: _loadSessions,
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
                playbackMs: _playbackMs,
                isPlaying: _isPlaying,
                onPlayPause: _togglePlayback,
                onSeek: _seekPlayback,
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
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 300, child: sessionList),
                  const SizedBox(height: 12),
                  SizedBox(height: 520, child: timeline),
                ],
              );
            },
          ),
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
        return FadeInSlide(
          delay: Duration(milliseconds: 30 * index),
          child: GlassCard(
            color: isSelected
                ? AppColors.teacherRole.withValues(alpha: 0.1)
                : null,
            borderColor: isSelected ? AppColors.teacherRole : null,
            padding: const EdgeInsets.all(12),
            onTap: () => onSelected(session),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.play_circle,
                  color: isSelected ? AppColors.teacherRole : AppColors.info,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium(
                          AppColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.lessonTitle} | ${session.durationSeconds}s | ${session.pagesRead} ${context.tr('pages')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall(
                          AppColors.darkTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: StatusChip(
                          label: session.startedLabel,
                          status: ChipStatus.neutral,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReplayTimeline extends StatelessWidget {
  final _ReplaySession? session;
  final List<_ReplayEvent> events;
  final int playbackMs;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;

  const _ReplayTimeline({
    required this.session,
    required this.events,
    required this.playbackMs,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final selected = session;
    if (selected == null) {
      return Center(child: Text(context.tr('Select a replay session.')));
    }
    if (events.isEmpty) {
      return Center(child: Text(context.tr('No events were recorded.')));
    }
    final maxMs = events.last.offsetMs <= 0 ? 1 : events.last.offsetMs;
    final visibleEvents = events
        .where((event) => event.offsetMs <= playbackMs)
        .toList();
    final currentEvent = visibleEvents.isEmpty
        ? events.first
        : visibleEvents.last;
    return ListView.separated(
      padding: const EdgeInsets.only(left: 12),
      itemCount: events.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return GlassCard(
            padding: const EdgeInsets.all(16),
            borderColor: AppColors.teacherRole,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 620;
                final sessionInfo = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleIcon(
                      icon: Icons.video_library,
                      color: AppColors.teacherRole,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected.lessonTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium(
                              AppColors.darkTextPrimary,
                            ),
                          ),
                          Text(
                            '${selected.studentName} | ${selected.startedLabel} | ${selected.durationSeconds}s',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall(
                              AppColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final controls = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: context.tr(
                            isPlaying ? 'Pause replay' : 'Play replay',
                          ),
                          onPressed: onPlayPause,
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: playbackMs.clamp(0, maxMs).toDouble(),
                            min: 0,
                            max: maxMs.toDouble(),
                            onChanged: onSeek,
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 64),
                          child: Text(
                            currentEvent.offsetLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${context.tr('Now')}: ${context.tr(currentEvent.eventType.replaceAll('_', ' '))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      sessionInfo,
                      const SizedBox(height: 12),
                      controls,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: sessionInfo),
                    const SizedBox(width: 12),
                    SizedBox(width: 320, child: controls),
                  ],
                );
              },
            ),
          );
        }
        final event = events[index - 1];
        final reached = event.offsetMs <= playbackMs;
        return FadeInSlide(
          delay: Duration(milliseconds: 10 * index),
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            color: reached
                ? event.color.withValues(alpha: 0.1)
                : AppColors.glassLight,
            borderColor: reached ? event.color : AppColors.glassBorder,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  reached ? event.icon : Icons.radio_button_unchecked,
                  color: reached ? event.color : Colors.grey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.eventType.replaceAll('_', ' '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium(
                          AppColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${event.offsetLabel} | ${event.payload}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall(
                          AppColors.darkTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: StatusChip(
                          label: event.kind,
                          status: ChipStatus.info,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
