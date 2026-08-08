import '../models/attendance_models.dart';

abstract class IClassSessionRepository {
  Future<List<ClassSession>> fetchSessionsForGroup(String groupId);
  Future<ClassSession> createClassSession(ClassSession session);
}

abstract class IAttendanceRepository {
  Future<List<AttendanceRecord>> fetchAttendanceForSession(String sessionId);
  Future<void> markSessionAttendance({
    required String sessionId,
    required List<Map<String, dynamic>> records,
  });
  Future<void> finalizeSessionAttendance(String sessionId);
  Future<AttendanceSummary> fetchStudentAttendanceSummary(String studentId);
}

abstract class ILeaveRepository {
  Future<List<LeaveRequest>> fetchLeaveRequestsForStudent(String studentId);
  Future<LeaveRequest> createLeaveRequest(LeaveRequest request);
  Future<void> reviewLeaveRequest({
    required String requestId,
    required String decision,
    String? reviewerNote,
  });
}

abstract class ICompensationRepository {
  Future<List<CompensationRequest>> fetchCompensationRequests(String studentId);
  Future<void> assignCompensation({
    required String requestId,
    required String targetSessionId,
  });
}
