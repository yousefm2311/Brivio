import 'package:equatable/equatable.dart';

class StudyLessonSummary extends Equatable {
  final String id;
  final String title;
  final String pathName;
  final String unitName;
  final int progressPercentage;
  final int estimatedMinutes;
  final int lastPage;
  final int totalPages;
  final int xp;
  final bool hasPdf;
  final bool hasCodePlayground;
  final String? pdfUrl;

  const StudyLessonSummary({
    required this.id,
    required this.title,
    required this.pathName,
    required this.unitName,
    required this.progressPercentage,
    required this.estimatedMinutes,
    required this.lastPage,
    required this.totalPages,
    required this.xp,
    required this.hasPdf,
    required this.hasCodePlayground,
    this.pdfUrl,
  });

  double get progress => progressPercentage.clamp(0, 100) / 100;

  StudyLessonSummary copyWith({int? progressPercentage, int? lastPage}) {
    return StudyLessonSummary(
      id: id,
      title: title,
      pathName: pathName,
      unitName: unitName,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      estimatedMinutes: estimatedMinutes,
      lastPage: lastPage ?? this.lastPage,
      totalPages: totalPages,
      xp: xp,
      hasPdf: hasPdf,
      hasCodePlayground: hasCodePlayground,
      pdfUrl: pdfUrl,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    pathName,
    unitName,
    progressPercentage,
    estimatedMinutes,
    lastPage,
    totalPages,
    xp,
    hasPdf,
    hasCodePlayground,
    pdfUrl,
  ];
}

class StudyMetric extends Equatable {
  final String label;
  final String value;
  final String helper;

  const StudyMetric({
    required this.label,
    required this.value,
    required this.helper,
  });

  @override
  List<Object?> get props => [label, value, helper];
}

class StudentGamificationSummary extends Equatable {
  final int totalXp;
  final int level;
  final int levelProgressPercentage;
  final int xpToNextLevel;
  final int streakDays;
  final int badgeCount;
  final DateTime? lastXpAt;
  final List<String> badges;

  const StudentGamificationSummary({
    required this.totalXp,
    required this.level,
    required this.levelProgressPercentage,
    required this.xpToNextLevel,
    required this.streakDays,
    required this.badgeCount,
    required this.lastXpAt,
    required this.badges,
  });

  static const empty = StudentGamificationSummary(
    totalXp: 0,
    level: 1,
    levelProgressPercentage: 0,
    xpToNextLevel: 500,
    streakDays: 0,
    badgeCount: 0,
    lastXpAt: null,
    badges: [],
  );

  factory StudentGamificationSummary.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    final badgeNames = (json['badges'] as List<dynamic>? ?? const [])
        .map((badge) {
          if (badge is Map) {
            return badge['name']?.toString() ?? '';
          }
          return badge.toString();
        })
        .where((name) => name.trim().isNotEmpty)
        .toList();

    return StudentGamificationSummary(
      totalXp: (json['total_xp'] as num?)?.round() ?? 0,
      level: (json['level'] as num?)?.round() ?? 1,
      levelProgressPercentage:
          (json['level_progress_percentage'] as num?)?.round() ?? 0,
      xpToNextLevel: (json['xp_to_next_level'] as num?)?.round() ?? 500,
      streakDays: (json['streak_days'] as num?)?.round() ?? 0,
      badgeCount: (json['badge_count'] as num?)?.round() ?? badgeNames.length,
      lastXpAt: DateTime.tryParse(json['last_xp_at']?.toString() ?? ''),
      badges: badgeNames,
    );
  }

  @override
  List<Object?> get props => [
    totalXp,
    level,
    levelProgressPercentage,
    xpToNextLevel,
    streakDays,
    badgeCount,
    lastXpAt,
    badges,
  ];
}

class StudentLearningSnapshot extends Equatable {
  final List<StudyLessonSummary> availableLessons;
  final List<StudyMetric> metrics;
  final int enrolledGroupCount;
  final StudentGamificationSummary gamification;

  const StudentLearningSnapshot({
    required this.availableLessons,
    required this.metrics,
    required this.enrolledGroupCount,
    this.gamification = StudentGamificationSummary.empty,
  });

  StudyLessonSummary? get nextLesson {
    if (availableLessons.isEmpty) return null;
    final inProgress = availableLessons.where(
      (lesson) =>
          lesson.progressPercentage > 0 && lesson.progressPercentage < 100,
    );
    if (inProgress.isNotEmpty) return inProgress.first;
    return availableLessons.first;
  }

  bool get hasContent => availableLessons.isNotEmpty;

  @override
  List<Object?> get props => [
    availableLessons,
    metrics,
    enrolledGroupCount,
    gamification,
  ];
}

class CodeRunResult extends Equatable {
  final String output;
  final bool isSuccess;

  const CodeRunResult({required this.output, required this.isSuccess});

  @override
  List<Object?> get props => [output, isSuccess];
}

class StudyWorkspaceDraft extends Equatable {
  final String notebookContent;
  final String code;
  final String boardData;

  const StudyWorkspaceDraft({
    required this.notebookContent,
    required this.code,
    this.boardData = '',
  });

  @override
  List<Object?> get props => [notebookContent, code, boardData];
}
