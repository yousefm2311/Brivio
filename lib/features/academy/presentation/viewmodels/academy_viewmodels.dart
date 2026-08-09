import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/models/academy_models.dart';
import '../../domain/repositories/academy_repositories.dart';

enum AcademyViewState { initial, loading, loaded, submitting, failure }

class StudentViewState {
  final AcademyViewState status;
  final List<Student> students;
  final int total;
  final int page;
  final String search;
  final String? branchId;
  final String? statusFilter;
  final Failure? failure;

  const StudentViewState({
    required this.status,
    this.students = const [],
    this.total = 0,
    this.page = 1,
    this.search = '',
    this.branchId,
    this.statusFilter,
    this.failure,
  });

  factory StudentViewState.initial() =>
      const StudentViewState(status: AcademyViewState.initial);

  StudentViewState copyWith({
    AcademyViewState? status,
    List<Student>? students,
    int? total,
    int? page,
    String? search,
    String? branchId,
    String? statusFilter,
    Failure? failure,
  }) {
    return StudentViewState(
      status: status ?? this.status,
      students: students ?? this.students,
      total: total ?? this.total,
      page: page ?? this.page,
      search: search ?? this.search,
      branchId: branchId ?? this.branchId,
      statusFilter: statusFilter ?? this.statusFilter,
      failure: failure ?? this.failure,
    );
  }
}

class StudentViewModel extends ChangeNotifier {
  final IStudentRepository _repository;
  StudentViewState _state = StudentViewState.initial();

  StudentViewModel(this._repository);

  StudentViewState get state => _state;

  Future<void> fetchStudents({
    String? search,
    String? branchId,
    String? statusFilter,
    int page = 1,
  }) async {
    _state = _state.copyWith(
      status: AcademyViewState.loading,
      search: search ?? _state.search,
      branchId: branchId ?? _state.branchId,
      statusFilter: statusFilter ?? _state.statusFilter,
      page: page,
    );
    notifyListeners();

    try {
      final result = await _repository.fetchStudents(
        search: _state.search,
        branchId: _state.branchId,
        status: _state.statusFilter,
        page: _state.page,
      );

      _state = _state.copyWith(
        status: AcademyViewState.loaded,
        students: result.data,
        total: result.total,
      );
    } on Failure catch (f) {
      _state = _state.copyWith(status: AcademyViewState.failure, failure: f);
    } catch (e) {
      _state = _state.copyWith(
        status: AcademyViewState.failure,
        failure: UnexpectedFailure(message: e.toString()),
      );
    }
    notifyListeners();
  }
}

class ParentViewState {
  final AcademyViewState status;
  final List<Parent> parents;
  final List<Student> linkedStudents;
  final int total;
  final int page;
  final String search;
  final Failure? failure;

  const ParentViewState({
    required this.status,
    this.parents = const [],
    this.linkedStudents = const [],
    this.total = 0,
    this.page = 1,
    this.search = '',
    this.failure,
  });

  factory ParentViewState.initial() =>
      const ParentViewState(status: AcademyViewState.initial);

  ParentViewState copyWith({
    AcademyViewState? status,
    List<Parent>? parents,
    List<Student>? linkedStudents,
    int? total,
    int? page,
    String? search,
    Failure? failure,
  }) {
    return ParentViewState(
      status: status ?? this.status,
      parents: parents ?? this.parents,
      linkedStudents: linkedStudents ?? this.linkedStudents,
      total: total ?? this.total,
      page: page ?? this.page,
      search: search ?? this.search,
      failure: failure ?? this.failure,
    );
  }
}

class ParentViewModel extends ChangeNotifier {
  final IParentRepository _repository;
  ParentViewState _state = ParentViewState.initial();

  ParentViewModel(this._repository);

  ParentViewState get state => _state;

  Future<void> fetchParents({String? search, int page = 1}) async {
    _state = _state.copyWith(
      status: AcademyViewState.loading,
      search: search ?? _state.search,
      page: page,
    );
    notifyListeners();

    try {
      final result = await _repository.fetchParents(
        search: _state.search,
        page: _state.page,
      );
      _state = _state.copyWith(
        status: AcademyViewState.loaded,
        parents: result.data,
        total: result.total,
      );
    } on Failure catch (f) {
      _state = _state.copyWith(status: AcademyViewState.failure, failure: f);
    } catch (e) {
      _state = _state.copyWith(
        status: AcademyViewState.failure,
        failure: UnexpectedFailure(message: e.toString()),
      );
    }
    notifyListeners();
  }

  Future<void> setPrimaryGuardian({
    required String parentId,
    required String studentId,
  }) async {
    _state = _state.copyWith(status: AcademyViewState.submitting);
    notifyListeners();

    try {
      await _repository.setPrimaryGuardian(
        parentId: parentId,
        studentId: studentId,
      );
      await fetchParents();
    } on Failure catch (f) {
      _state = _state.copyWith(status: AcademyViewState.failure, failure: f);
      notifyListeners();
    }
  }
}

class TeacherViewModel extends ChangeNotifier {
  final ITeacherRepository _repository;
  AcademyViewState _status = AcademyViewState.initial;
  List<Teacher> _teachers = [];
  List<GroupEntity> _assignedGroups = [];
  Failure? _failure;

  TeacherViewModel(this._repository);

  AcademyViewState get status => _status;
  List<Teacher> get teachers => _teachers;
  List<GroupEntity> get assignedGroups => _assignedGroups;
  Failure? get failure => _failure;

  Future<void> fetchTeachers({String? search, String? branchId}) async {
    _status = AcademyViewState.loading;
    notifyListeners();

    try {
      final result = await _repository.fetchTeachers(
        search: search,
        branchId: branchId,
      );
      _teachers = result.data;
      _status = AcademyViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = AcademyViewState.failure;
    }
    notifyListeners();
  }

  Future<void> fetchAssignedGroups(String teacherId) async {
    try {
      _assignedGroups = await _repository.fetchAssignedGroups(teacherId);
      notifyListeners();
    } catch (e) {
      _failure = DatabaseFailure(message: e.toString());
      notifyListeners();
    }
  }
}

class BranchViewModel extends ChangeNotifier {
  final IBranchRepository _repository;
  AcademyViewState _status = AcademyViewState.initial;
  List<Branch> _branches = [];
  String? _search;
  String? _statusFilter;
  Failure? _failure;

  BranchViewModel(this._repository);

  AcademyViewState get status => _status;
  List<Branch> get branches => _branches;
  String? get search => _search;
  String? get statusFilter => _statusFilter;
  Failure? get failure => _failure;

  Future<void> fetchBranches({String? search, String? statusFilter}) async {
    _status = AcademyViewState.loading;
    _search = search ?? _search;
    _statusFilter = statusFilter ?? _statusFilter;
    notifyListeners();

    try {
      _branches = await _repository.fetchBranches(
        search: _search,
        status: _statusFilter,
      );
      _status = AcademyViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = AcademyViewState.failure;
    } catch (e) {
      _failure = UnexpectedFailure(message: e.toString());
      _status = AcademyViewState.failure;
    }
    notifyListeners();
  }

  Future<void> createBranch(Branch branch) async {
    _status = AcademyViewState.submitting;
    notifyListeners();

    try {
      await _repository.createBranch(branch);
      await fetchBranches();
    } on Failure catch (f) {
      _failure = f;
      _status = AcademyViewState.failure;
      notifyListeners();
    }
  }

  Future<void> updateBranch(Branch branch) async {
    _status = AcademyViewState.submitting;
    notifyListeners();

    try {
      await _repository.updateBranch(branch);
      await fetchBranches();
    } on Failure catch (f) {
      _failure = f;
      _status = AcademyViewState.failure;
      notifyListeners();
    }
  }
}

class SubjectViewModel extends ChangeNotifier {
  final ISubjectRepository _repository;
  AcademyViewState _status = AcademyViewState.initial;
  List<SubjectEntity> _subjects = [];
  String? _search;
  String? _statusFilter;
  Failure? _failure;

  SubjectViewModel(this._repository);

  AcademyViewState get status => _status;
  List<SubjectEntity> get subjects => _subjects;
  String? get search => _search;
  String? get statusFilter => _statusFilter;
  Failure? get failure => _failure;

  Future<void> fetchSubjects({String? search, String? statusFilter}) async {
    _status = AcademyViewState.loading;
    _search = search ?? _search;
    _statusFilter = statusFilter ?? _statusFilter;
    notifyListeners();

    try {
      _subjects = await _repository.fetchSubjects(
        search: _search,
        status: _statusFilter,
      );
      _status = AcademyViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = AcademyViewState.failure;
    } catch (e) {
      _failure = UnexpectedFailure(message: e.toString());
      _status = AcademyViewState.failure;
    }
    notifyListeners();
  }

  Future<void> createSubject(SubjectEntity subject) async {
    _status = AcademyViewState.submitting;
    notifyListeners();

    try {
      await _repository.createSubject(subject);
      await fetchSubjects();
    } on Failure catch (f) {
      _failure = f;
      _status = AcademyViewState.failure;
      notifyListeners();
    }
  }

  Future<void> updateSubject(SubjectEntity subject) async {
    _status = AcademyViewState.submitting;
    notifyListeners();

    try {
      await _repository.updateSubject(subject);
      await fetchSubjects();
    } on Failure catch (f) {
      _failure = f;
      _status = AcademyViewState.failure;
      notifyListeners();
    }
  }
}

class GroupViewModel extends ChangeNotifier {
  final IGroupRepository _repository;
  AcademyViewState _status = AcademyViewState.initial;
  List<GroupEntity> _groups = [];
  Failure? _failure;

  GroupViewModel(this._repository);

  AcademyViewState get status => _status;
  List<GroupEntity> get groups => _groups;
  Failure? get failure => _failure;

  Future<void> fetchGroups({String? branchId, String? subjectId}) async {
    _status = AcademyViewState.loading;
    notifyListeners();

    try {
      _groups = await _repository.fetchGroups(
        branchId: branchId,
        subjectId: subjectId,
      );
      _status = AcademyViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = AcademyViewState.failure;
    }
    notifyListeners();
  }
}

class EnrollmentViewModel extends ChangeNotifier {
  final IEnrollmentRepository _repository;
  AcademyViewState _status = AcademyViewState.initial;
  final List<EnrollmentEntity> _enrollments = [];
  Failure? _failure;

  EnrollmentViewModel(this._repository);

  AcademyViewState get status => _status;
  List<EnrollmentEntity> get enrollments => _enrollments;
  Failure? get failure => _failure;

  Future<void> enrollStudent({
    required String studentId,
    required String groupId,
    int totalMinor = 0,
    int discountMinor = 0,
    String currency = 'EGP',
  }) async {
    _status = AcademyViewState.submitting;
    _failure = null;
    notifyListeners();

    try {
      await _repository.enrollStudentInGroup(
        studentId: studentId,
        groupId: groupId,
        totalMinor: totalMinor,
        discountMinor: discountMinor,
        currency: currency,
      );
      _status = AcademyViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = AcademyViewState.failure;
    } catch (e) {
      _failure = UnexpectedFailure(message: e.toString());
      _status = AcademyViewState.failure;
    }
    notifyListeners();
  }
}

class ScheduleViewModel extends ChangeNotifier {
  final IScheduleRepository _repository;
  AcademyViewState _status = AcademyViewState.initial;
  List<ScheduleEntity> _schedules = [];
  Failure? _failure;

  ScheduleViewModel(this._repository);

  AcademyViewState get status => _status;
  List<ScheduleEntity> get schedules => _schedules;
  Failure? get failure => _failure;

  Future<void> fetchSchedules(String groupId) async {
    _status = AcademyViewState.loading;
    notifyListeners();

    try {
      _schedules = await _repository.fetchSchedulesForGroup(groupId);
      _status = AcademyViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = AcademyViewState.failure;
    }
    notifyListeners();
  }

  Future<void> createSchedule({
    required String groupId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? roomLocation,
  }) async {
    _status = AcademyViewState.submitting;
    _failure = null;
    notifyListeners();

    try {
      await _repository.createSchedule(
        groupId: groupId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        roomLocation: roomLocation,
      );
      await fetchSchedules(groupId);
    } on Failure catch (f) {
      _failure = f;
      _status = AcademyViewState.failure;
      notifyListeners();
    }
  }
}

class AcademyDashboardViewModel extends ChangeNotifier {
  final IAcademySummaryRepository _summaryRepository;
  AcademyViewState _status = AcademyViewState.initial;
  AcademyCoreSummary? _summary;
  Failure? _failure;

  AcademyDashboardViewModel(this._summaryRepository);

  AcademyViewState get status => _status;
  AcademyCoreSummary? get summary => _summary;
  Failure? get failure => _failure;

  Future<void> loadDashboardSummary() async {
    _status = AcademyViewState.loading;
    notifyListeners();

    try {
      _summary = await _summaryRepository.fetchSummary();
      _status = AcademyViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = AcademyViewState.failure;
    } catch (e) {
      _failure = UnexpectedFailure(message: e.toString());
      _status = AcademyViewState.failure;
    }
    notifyListeners();
  }
}
