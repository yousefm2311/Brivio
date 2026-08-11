import 'package:flutter/material.dart';
import '../../../features/assessment/domain/models/assessment_models.dart';

class StudentHomeworkItem {
  final Homework homework;
  final String groupName;
  final String? submissionStatus;
  final double? submissionScore;
  final String? teacherFeedback;
  final DateTime? submittedAt;

  const StudentHomeworkItem({required this.homework, required this.groupName, this.submissionStatus, this.submissionScore, this.teacherFeedback, this.submittedAt});

  bool get isSubmitted => submissionStatus == 'submitted' || submissionStatus == 'graded';
  bool get isGraded => submissionStatus == 'graded';

  factory StudentHomeworkItem.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return StudentHomeworkItem(
      homework: Homework.fromJson(json),
      groupName: json['group_name'] as String? ?? 'Group',
      submissionStatus: json['submission_status'] as String?,
      submissionScore: (json['submission_score'] as num?)?.toDouble(),
      teacherFeedback: json['teacher_feedback'] as String?,
      submittedAt: json['submitted_at'] == null ? null : DateTime.tryParse(json['submitted_at'].toString()),
    );
  }
}

class StudentExamItem {
  final Exam exam;
  final String groupName;
  final int attemptCount;
  final String? lastAttemptStatus;
  final double? lastScore;
  final String? resetRequestStatus;

  const StudentExamItem({
    required this.exam, 
    required this.groupName, 
    required this.attemptCount, 
    this.lastAttemptStatus, 
    this.lastScore,
    this.resetRequestStatus,
  });

  bool get canStart {
    return attemptCount < exam.maxAttempts;
  }

  factory StudentExamItem.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return StudentExamItem(
      exam: Exam.fromJson(json),
      groupName: json['group_name'] as String? ?? 'Group',
      attemptCount: json['attempt_count'] as int? ?? 0,
      lastAttemptStatus: json['last_attempt_status'] as String?,
      lastScore: (json['last_score'] as num?)?.toDouble(),
      resetRequestStatus: json['reset_request_status'] as String?,
    );
  }
}

class StudentAttendanceItem {
  final String id;
  final String classSessionId;
  final String status;
  final DateTime markedAt;
  final DateTime sessionDate;
  final DateTime scheduledStartAt;
  final DateTime scheduledEndAt;
  final String groupName;
  final String? notes;

  const StudentAttendanceItem({required this.id, required this.classSessionId, required this.status, required this.markedAt, required this.sessionDate, required this.scheduledStartAt, required this.scheduledEndAt, required this.groupName, this.notes});

  factory StudentAttendanceItem.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    final groupName = [json['group_name'] as String? ?? 'Group', json['group_code'] as String? ?? ''].where((p) => p.trim().isNotEmpty).join(' ');
    return StudentAttendanceItem(
      id: json['id'] as String? ?? '',
      classSessionId: json['class_session_id'] as String? ?? '',
      status: json['attendance_status'] as String? ?? 'present',
      markedAt: DateTime.tryParse(json['marked_at']?.toString() ?? '') ?? DateTime.now(),
      sessionDate: DateTime.tryParse(json['session_date']?.toString() ?? '') ?? DateTime.now(),
      scheduledStartAt: DateTime.tryParse(json['scheduled_start_at']?.toString() ?? '') ?? DateTime.now(),
      scheduledEndAt: DateTime.tryParse(json['scheduled_end_at']?.toString() ?? '') ?? DateTime.now(),
      groupName: groupName,
      notes: json['notes'] as String?,
    );
  }
}

class StudentLeaveItem {
  final String id;
  final String? classSessionId;
  final String reason;
  final String status;
  final DateTime submittedAt;
  final String? reviewerNote;
  final DateTime? sessionDate;
  final String groupName;

  const StudentLeaveItem({required this.id, this.classSessionId, required this.reason, required this.status, required this.submittedAt, this.reviewerNote, this.sessionDate, required this.groupName});

  factory StudentLeaveItem.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return StudentLeaveItem(
      id: json['id'] as String? ?? '',
      classSessionId: json['class_session_id'] as String?,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? '') ?? DateTime.now(),
      reviewerNote: json['reviewer_note'] as String?,
      sessionDate: DateTime.tryParse(json['session_date']?.toString() ?? ''),
      groupName: json['group_name'] as String? ?? 'General',
    );
  }
}

class PublishedSessionBoard {
  final String id;
  final String title;
  final String groupName;
  final DateTime sessionDate;
  final DateTime updatedAt;
  final Map<String, dynamic> boardData;

  const PublishedSessionBoard({required this.id, required this.title, required this.groupName, required this.sessionDate, required this.updatedAt, required this.boardData});

  factory PublishedSessionBoard.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    final title = json['title'] as String?;
    return PublishedSessionBoard(
      id: json['id'] as String? ?? '',
      title: title == null || title.trim().isEmpty ? 'Published session board' : title,
      groupName: json['group_name'] as String? ?? 'Group',
      sessionDate: DateTime.tryParse(json['session_date']?.toString() ?? '') ?? DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      boardData: Map<String, dynamic>.from(json['board_data'] as Map? ?? {}),
    );
  }
}

class BoardStroke {
  final Color color;
  final double width;
  final List<Offset> points;

  const BoardStroke({required this.color, required this.width, required this.points});

  static BoardStroke fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? [];
    return BoardStroke(
      color: Color(json['color'] as int? ?? 0xFF111827),
      width: (json['width'] as num? ?? 4).toDouble(),
      points: rawPoints.map((p) {
        final pt = Map<String, dynamic>.from(p as Map);
        return Offset((pt['x'] as num? ?? 0).toDouble(), (pt['y'] as num? ?? 0).toDouble());
      }).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color': color.value,
      'width': width,
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    };
  }
}

List<BoardStroke> decodeSessionBoard(Map<String, dynamic> data) {
  try {
    return (data['strokes'] as List<dynamic>? ?? []).map((s) => BoardStroke.fromJson(Map<String, dynamic>.from(s as Map))).toList();
  } catch (_) { return []; }
}
