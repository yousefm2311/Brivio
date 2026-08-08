import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../../core/errors/failures.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/attendance_models.dart';
import '../../domain/repositories/attendance_repositories.dart';

class SupabaseClassSessionRepository implements IClassSessionRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseClassSessionRepository(this._wrapper);

  @override
  Future<List<ClassSession>> fetchSessionsForGroup(String groupId) async {
    try {
      final response = await _wrapper.client
          .from('class_sessions')
          .select()
          .eq('group_id', groupId)
          .order('session_date', ascending: false);
      return (response as List)
          .map((j) => ClassSession.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch class sessions: ${e.toString()}',
      );
    }
  }

  @override
  Future<ClassSession> createClassSession(ClassSession session) async {
    try {
      final response = await _wrapper.client
          .from('class_sessions')
          .insert({
            'group_id': session.groupId,
            'schedule_id': session.scheduleId,
            'session_date': session.sessionDate.toIso8601String().split('T')[0],
            'scheduled_start_at': session.scheduledStartAt.toIso8601String(),
            'scheduled_end_at': session.scheduledEndAt.toIso8601String(),
            'status': session.status.toDbValue(),
            'location': session.location,
          })
          .select()
          .single();
      return ClassSession.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to create class session: ${e.toString()}',
      );
    }
  }
}

class SupabaseAttendanceRepository implements IAttendanceRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseAttendanceRepository(this._wrapper);

  @override
  Future<List<AttendanceRecord>> fetchAttendanceForSession(
    String sessionId,
  ) async {
    try {
      final response = await _wrapper.client
          .from('attendance_records')
          .select()
          .eq('class_session_id', sessionId);
      return (response as List)
          .map((j) => AttendanceRecord.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch session attendance: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> markSessionAttendance({
    required String sessionId,
    required List<Map<String, dynamic>> records,
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'mark_session_attendance',
        params: {'p_session_id': sessionId, 'p_records': records},
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(message: 'Mark attendance operation failed');
      }
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(message: 'Mark attendance failed: ${e.toString()}');
    }
  }

  @override
  Future<void> finalizeSessionAttendance(String sessionId) async {
    try {
      final response = await _wrapper.client.rpc(
        'finalize_session_attendance',
        params: {'p_session_id': sessionId},
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(message: 'Finalize attendance operation failed');
      }
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Finalize attendance failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<AttendanceSummary> fetchStudentAttendanceSummary(
    String studentId,
  ) async {
    try {
      final response = await _wrapper.client.rpc(
        'get_student_attendance_summary',
        params: {'p_student_id': studentId},
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      return AttendanceSummary(
        totalSessions: jsonMap['total_sessions'] as int? ?? 0,
        presentCount: jsonMap['present_count'] as int? ?? 0,
        absentCount: jsonMap['absent_count'] as int? ?? 0,
        lateCount: jsonMap['late_count'] as int? ?? 0,
        excusedCount: jsonMap['excused_count'] as int? ?? 0,
        attendancePercentage:
            (jsonMap['attendance_percentage'] as num? ?? 100.0).toDouble(),
      );
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch attendance summary: ${e.toString()}',
      );
    }
  }
}

class SupabaseLeaveRepository implements ILeaveRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseLeaveRepository(this._wrapper);

  @override
  Future<List<LeaveRequest>> fetchLeaveRequestsForStudent(
    String studentId,
  ) async {
    try {
      final response = await _wrapper.client
          .from('leave_requests')
          .select()
          .eq('student_id', studentId)
          .order('submitted_at', ascending: false);
      return (response as List)
          .map((j) => LeaveRequest.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch leave requests: ${e.toString()}',
      );
    }
  }

  @override
  Future<LeaveRequest> createLeaveRequest(LeaveRequest request) async {
    try {
      final response = await _wrapper.client
          .from('leave_requests')
          .insert({
            'student_id': request.studentId,
            'class_session_id': request.classSessionId,
            'reason': request.reason,
            'status': request.status,
          })
          .select()
          .single();
      return LeaveRequest.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to create leave request: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> reviewLeaveRequest({
    required String requestId,
    required String decision,
    String? reviewerNote,
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'review_leave_request',
        params: {
          'p_request_id': requestId,
          'p_decision': decision,
          'p_reviewer_note': reviewerNote,
        },
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(message: 'Review leave request operation failed');
      }
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Review leave request failed: ${e.toString()}',
      );
    }
  }
}

class SupabaseCompensationRepository implements ICompensationRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseCompensationRepository(this._wrapper);

  @override
  Future<List<CompensationRequest>> fetchCompensationRequests(
    String studentId,
  ) async {
    try {
      final response = await _wrapper.client
          .from('compensation_requests')
          .select()
          .eq('student_id', studentId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((j) => CompensationRequest.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch compensation requests: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> assignCompensation({
    required String requestId,
    required String targetSessionId,
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'assign_compensation_session',
        params: {
          'p_request_id': requestId,
          'p_target_session_id': targetSessionId,
        },
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(message: 'Assign compensation operation failed');
      }
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Assign compensation failed: ${e.toString()}',
      );
    }
  }
}
