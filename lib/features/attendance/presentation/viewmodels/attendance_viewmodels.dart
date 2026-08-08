import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/models/attendance_models.dart';
import '../../domain/repositories/attendance_repositories.dart';

enum AttendanceViewState { initial, loading, loaded, submitting, failure }

class ClassSessionViewModel extends ChangeNotifier {
  final IClassSessionRepository _repository;
  AttendanceViewState _status = AttendanceViewState.initial;
  List<ClassSession> _sessions = [];
  Failure? _failure;

  ClassSessionViewModel(this._repository);

  AttendanceViewState get status => _status;
  List<ClassSession> get sessions => _sessions;
  Failure? get failure => _failure;

  Future<void> fetchSessions(String groupId) async {
    _status = AttendanceViewState.loading;
    notifyListeners();

    try {
      _sessions = await _repository.fetchSessionsForGroup(groupId);
      _status = AttendanceViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = AttendanceViewState.failure;
    }
    notifyListeners();
  }

  Future<void> createSession(ClassSession session) async {
    _status = AttendanceViewState.submitting;
    notifyListeners();

    try {
      await _repository.createClassSession(session);
      await fetchSessions(session.groupId);
    } on Failure catch (f) {
      _failure = f;
      _status = AttendanceViewState.failure;
      notifyListeners();
    }
  }
}

class AttendanceRosterViewModel extends ChangeNotifier {
  final IAttendanceRepository _repository;
  AttendanceViewState _status = AttendanceViewState.initial;
  List<AttendanceRecord> _records = [];
  AttendanceSummary? _summary;
  Failure? _failure;

  AttendanceRosterViewModel(this._repository);

  AttendanceViewState get status => _status;
  List<AttendanceRecord> get records => _records;
  AttendanceSummary? get summary => _summary;
  Failure? get failure => _failure;

  Future<void> fetchSessionAttendance(String sessionId) async {
    _status = AttendanceViewState.loading;
    notifyListeners();

    try {
      _records = await _repository.fetchAttendanceForSession(sessionId);
      _status = AttendanceViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = AttendanceViewState.failure;
    }
    notifyListeners();
  }

  Future<void> markAttendance({
    required String sessionId,
    required List<Map<String, dynamic>> items,
  }) async {
    _status = AttendanceViewState.submitting;
    notifyListeners();

    try {
      await _repository.markSessionAttendance(
        sessionId: sessionId,
        records: items,
      );
      await fetchSessionAttendance(sessionId);
    } on Failure catch (f) {
      _failure = f;
      _status = AttendanceViewState.failure;
      notifyListeners();
    }
  }

  Future<void> finalizeAttendance(String sessionId) async {
    _status = AttendanceViewState.submitting;
    notifyListeners();

    try {
      await _repository.finalizeSessionAttendance(sessionId);
      await fetchSessionAttendance(sessionId);
    } on Failure catch (f) {
      _failure = f;
      _status = AttendanceViewState.failure;
      notifyListeners();
    }
  }

  Future<void> fetchStudentSummary(String studentId) async {
    try {
      _summary = await _repository.fetchStudentAttendanceSummary(studentId);
      notifyListeners();
    } catch (e) {
      _failure = DatabaseFailure(message: e.toString());
      notifyListeners();
    }
  }
}

class LeaveRequestViewModel extends ChangeNotifier {
  final ILeaveRepository _repository;
  AttendanceViewState _status = AttendanceViewState.initial;
  List<LeaveRequest> _requests = [];
  Failure? _failure;

  LeaveRequestViewModel(this._repository);

  AttendanceViewState get status => _status;
  List<LeaveRequest> get requests => _requests;
  Failure? get failure => _failure;

  Future<void> fetchLeaveRequests(String studentId) async {
    _status = AttendanceViewState.loading;
    notifyListeners();

    try {
      _requests = await _repository.fetchLeaveRequestsForStudent(studentId);
      _status = AttendanceViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = AttendanceViewState.failure;
    }
    notifyListeners();
  }

  Future<void> createLeaveRequest(LeaveRequest request) async {
    _status = AttendanceViewState.submitting;
    notifyListeners();

    try {
      await _repository.createLeaveRequest(request);
      await fetchLeaveRequests(request.studentId);
    } on Failure catch (f) {
      _failure = f;
      _status = AttendanceViewState.failure;
      notifyListeners();
    }
  }
}

class CompensationViewModel extends ChangeNotifier {
  final ICompensationRepository _repository;
  AttendanceViewState _status = AttendanceViewState.initial;
  List<CompensationRequest> _compensations = [];
  Failure? _failure;

  CompensationViewModel(this._repository);

  AttendanceViewState get status => _status;
  List<CompensationRequest> get compensations => _compensations;
  Failure? get failure => _failure;

  Future<void> fetchCompensations(String studentId) async {
    _status = AttendanceViewState.loading;
    notifyListeners();

    try {
      _compensations = await _repository.fetchCompensationRequests(studentId);
      _status = AttendanceViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = AttendanceViewState.failure;
    }
    notifyListeners();
  }

  Future<void> assignCompensation({
    required String requestId,
    required String targetSessionId,
    required String studentId,
  }) async {
    _status = AttendanceViewState.submitting;
    notifyListeners();

    try {
      await _repository.assignCompensation(
        requestId: requestId,
        targetSessionId: targetSessionId,
      );
      await fetchCompensations(studentId);
    } on Failure catch (f) {
      _failure = f;
      _status = AttendanceViewState.failure;
      notifyListeners();
    }
  }
}
