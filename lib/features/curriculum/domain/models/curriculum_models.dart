import 'package:equatable/equatable.dart';

enum LessonType {
  video,
  pdf,
  text,
  programming,
  quiz;

  static LessonType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'video':
        return LessonType.video;
      case 'pdf':
        return LessonType.pdf;
      case 'text':
        return LessonType.text;
      case 'programming':
        return LessonType.programming;
      case 'quiz':
        return LessonType.quiz;
      default:
        return LessonType.text;
    }
  }

  String toDbValue() => name;
}

enum LessonStatus {
  draft,
  published,
  archived;

  static LessonStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'draft':
        return LessonStatus.draft;
      case 'published':
        return LessonStatus.published;
      case 'archived':
        return LessonStatus.archived;
      default:
        return LessonStatus.draft;
    }
  }

  String toDbValue() => name;
}

class Semester extends Equatable {
  final String id;
  final String subjectId;
  final String name;
  final String code;
  final int orderNumber;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final List<Unit> units;

  const Semester({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.code,
    required this.orderNumber,
    this.startDate,
    this.endDate,
    required this.status,
    this.units = const [],
  });

  factory Semester.fromJson(
    Map<String, dynamic> json, [
    List<Unit> u = const [],
  ]) => Semester(
    id: json['id'] as String,
    subjectId: json['subject_id'] as String,
    name: json['name'] as String,
    code: json['code'] as String,
    orderNumber: json['order_number'] as int? ?? 1,
    startDate: json['start_date'] != null
        ? DateTime.parse(json['start_date'] as String)
        : null,
    endDate: json['end_date'] != null
        ? DateTime.parse(json['end_date'] as String)
        : null,
    status: json['status'] as String? ?? 'active',
    units: u,
  );

  @override
  List<Object?> get props => [
    id,
    subjectId,
    name,
    code,
    orderNumber,
    startDate,
    endDate,
    status,
    units,
  ];
}

class Unit extends Equatable {
  final String id;
  final String semesterId;
  final String name;
  final String code;
  final int orderNumber;
  final String status;
  final List<Lesson> lessons;

  const Unit({
    required this.id,
    required this.semesterId,
    required this.name,
    required this.code,
    required this.orderNumber,
    required this.status,
    this.lessons = const [],
  });

  factory Unit.fromJson(
    Map<String, dynamic> json, [
    List<Lesson> l = const [],
  ]) => Unit(
    id: json['id'] as String,
    semesterId: json['semester_id'] as String,
    name: json['name'] as String,
    code: json['code'] as String,
    orderNumber: json['order_number'] as int? ?? 1,
    status: json['status'] as String? ?? 'active',
    lessons: l,
  );

  @override
  List<Object?> get props => [
    id,
    semesterId,
    name,
    code,
    orderNumber,
    status,
    lessons,
  ];
}

class LessonResource extends Equatable {
  final String id;
  final String lessonId;
  final String resourceType;
  final String title;
  final String bucket;
  final String objectPath;
  final int orderNumber;

  const LessonResource({
    required this.id,
    required this.lessonId,
    required this.resourceType,
    required this.title,
    required this.bucket,
    required this.objectPath,
    required this.orderNumber,
  });

  factory LessonResource.fromJson(Map<String, dynamic> json) => LessonResource(
    id: json['id'] as String,
    lessonId: json['lesson_id'] as String,
    resourceType: json['resource_type'] as String,
    title: json['title'] as String,
    bucket: json['bucket'] as String? ?? 'curriculum_assets',
    objectPath: json['object_path'] as String,
    orderNumber: json['order_number'] as int? ?? 1,
  );

  @override
  List<Object?> get props => [
    id,
    lessonId,
    resourceType,
    title,
    bucket,
    objectPath,
    orderNumber,
  ];
}

class Lesson extends Equatable {
  final String id;
  final String unitId;
  final String title;
  final LessonType lessonType;
  final int orderNumber;
  final LessonStatus status;
  final DateTime? publishedAt;
  final int? estimatedDurationMinutes;
  final List<LessonResource> resources;

  const Lesson({
    required this.id,
    required this.unitId,
    required this.title,
    required this.lessonType,
    required this.orderNumber,
    required this.status,
    this.publishedAt,
    this.estimatedDurationMinutes,
    this.resources = const [],
  });

  factory Lesson.fromJson(
    Map<String, dynamic> json, [
    List<LessonResource> res = const [],
  ]) => Lesson(
    id: json['id'] as String,
    unitId: json['unit_id'] as String,
    title: json['title'] as String,
    lessonType: LessonType.fromString(json['lesson_type'] as String? ?? 'text'),
    orderNumber: json['order_number'] as int? ?? 1,
    status: LessonStatus.fromString(json['status'] as String? ?? 'draft'),
    publishedAt: json['published_at'] != null
        ? DateTime.parse(json['published_at'] as String)
        : null,
    estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
    resources: res,
  );

  @override
  List<Object?> get props => [
    id,
    unitId,
    title,
    lessonType,
    orderNumber,
    status,
    publishedAt,
    estimatedDurationMinutes,
    resources,
  ];
}

class LessonProgress extends Equatable {
  final String studentId;
  final String lessonId;
  final String status;
  final int progressPercentage;
  final int lastPositionSeconds;
  final int timeSpentSeconds;
  final DateTime? completedAt;

  const LessonProgress({
    required this.studentId,
    required this.lessonId,
    required this.status,
    required this.progressPercentage,
    required this.lastPositionSeconds,
    required this.timeSpentSeconds,
    this.completedAt,
  });

  factory LessonProgress.fromJson(Map<String, dynamic> json) => LessonProgress(
    studentId: json['student_id'] as String,
    lessonId: json['lesson_id'] as String,
    status: json['status'] as String? ?? 'not_started',
    progressPercentage: json['progress_percentage'] as int? ?? 0,
    lastPositionSeconds: json['last_position_seconds'] as int? ?? 0,
    timeSpentSeconds: json['time_spent_seconds'] as int? ?? 0,
    completedAt: json['completed_at'] != null
        ? DateTime.parse(json['completed_at'] as String)
        : null,
  );

  @override
  List<Object?> get props => [
    studentId,
    lessonId,
    status,
    progressPercentage,
    lastPositionSeconds,
    timeSpentSeconds,
    completedAt,
  ];
}
