enum SessionStatus { scheduled, inProgress, completed, cancelled }

extension SessionStatusExtension on SessionStatus {
  String toDbValue() {
    switch (this) {
      case SessionStatus.scheduled:
        return 'scheduled';
      case SessionStatus.inProgress:
        return 'in_progress';
      case SessionStatus.completed:
        return 'completed';
      case SessionStatus.cancelled:
        return 'cancelled';
    }
  }

  static SessionStatus fromString(String val) {
    switch (val) {
      case 'in_progress':
        return SessionStatus.inProgress;
      case 'completed':
        return SessionStatus.completed;
      case 'cancelled':
        return SessionStatus.cancelled;
      case 'scheduled':
      default:
        return SessionStatus.scheduled;
    }
  }
}

enum AttendanceStatus { present, absent, late, excused }

extension AttendanceStatusExtension on AttendanceStatus {
  String toDbValue() {
    switch (this) {
      case AttendanceStatus.present:
        return 'present';
      case AttendanceStatus.absent:
        return 'absent';
      case AttendanceStatus.late:
        return 'late';
      case AttendanceStatus.excused:
        return 'excused';
    }
  }

  static AttendanceStatus fromString(String val) {
    switch (val) {
      case 'present':
        return AttendanceStatus.present;
      case 'absent':
        return AttendanceStatus.absent;
      case 'late':
        return AttendanceStatus.late;
      case 'excused':
        return AttendanceStatus.excused;
      default:
        return AttendanceStatus.present;
    }
  }
}

class ClassSession {
  final String id;
  final String groupId;
  final String? scheduleId;
  final DateTime sessionDate;
  final DateTime scheduledStartAt;
  final DateTime scheduledEndAt;
  final SessionStatus status;
  final String? location;

  ClassSession({
    required this.id,
    required this.groupId,
    this.scheduleId,
    required this.sessionDate,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
    this.status = SessionStatus.scheduled,
    this.location,
  });

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    return ClassSession(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      scheduleId: json['schedule_id'] as String?,
      sessionDate:
          DateTime.tryParse(json['session_date'] as String? ?? '') ??
          DateTime.now(),
      scheduledStartAt:
          DateTime.tryParse(json['scheduled_start_at'] as String? ?? '') ??
          DateTime.now(),
      scheduledEndAt:
          DateTime.tryParse(json['scheduled_end_at'] as String? ?? '') ??
          DateTime.now(),
      status: SessionStatusExtension.fromString(
        json['status'] as String? ?? 'scheduled',
      ),
      location: json['location'] as String?,
    );
  }
}

class AttendanceRecord {
  final String id;
  final String classSessionId;
  final String studentId;
  final AttendanceStatus attendanceStatus;
  final String? markedBy;
  final DateTime markedAt;
  final String? notes;

  AttendanceRecord({
    required this.id,
    required this.classSessionId,
    required this.studentId,
    required this.attendanceStatus,
    this.markedBy,
    required this.markedAt,
    this.notes,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      classSessionId: json['class_session_id'] as String,
      studentId: json['student_id'] as String,
      attendanceStatus: AttendanceStatusExtension.fromString(
        json['attendance_status'] as String? ?? 'present',
      ),
      markedBy: json['marked_by'] as String?,
      markedAt:
          DateTime.tryParse(json['marked_at'] as String? ?? '') ??
          DateTime.now(),
      notes: json['notes'] as String?,
    );
  }
}

class LeaveRequest {
  final String id;
  final String studentId;
  final String? classSessionId;
  final String reason;
  final String status;
  final DateTime submittedAt;
  final String? reviewerNote;

  LeaveRequest({
    required this.id,
    required this.studentId,
    this.classSessionId,
    required this.reason,
    this.status = 'pending',
    required this.submittedAt,
    this.reviewerNote,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      classSessionId: json['class_session_id'] as String?,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      submittedAt:
          DateTime.tryParse(json['submitted_at'] as String? ?? '') ??
          DateTime.now(),
      reviewerNote: json['reviewer_note'] as String?,
    );
  }
}

class CompensationRequest {
  final String id;
  final String studentId;
  final String originalSessionId;
  final String targetSessionId;
  final String? reason;
  final String status;

  CompensationRequest({
    required this.id,
    required this.studentId,
    required this.originalSessionId,
    required this.targetSessionId,
    this.reason,
    this.status = 'pending',
  });

  factory CompensationRequest.fromJson(Map<String, dynamic> json) {
    return CompensationRequest(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      originalSessionId: json['original_session_id'] as String,
      targetSessionId: json['target_session_id'] as String,
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'pending',
    );
  }
}

class AttendanceSummary {
  final int totalSessions;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;
  final double attendancePercentage;

  AttendanceSummary({
    required this.totalSessions,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.excusedCount,
    required this.attendancePercentage,
  });
}
