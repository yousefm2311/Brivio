import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/models/curriculum_models.dart';
import '../../domain/repositories/curriculum_repositories.dart';

enum CurriculumViewState { initial, loading, loaded, submitting, failure }

class CurriculumViewModel extends ChangeNotifier {
  final ISemesterRepository _semesterRepo;
  final IUnitRepository _unitRepo;
  final ILessonRepository _lessonRepo;

  CurriculumViewState _status = CurriculumViewState.initial;
  List<Semester> _semesters = [];
  List<Unit> _units = [];
  List<Lesson> _lessons = [];
  Failure? _failure;

  CurriculumViewModel(this._semesterRepo, this._unitRepo, this._lessonRepo);

  CurriculumViewState get status => _status;
  List<Semester> get semesters => _semesters;
  List<Unit> get units => _units;
  List<Lesson> get lessons => _lessons;
  Failure? get failure => _failure;

  Future<void> loadCurriculumForSubject(String subjectId) async {
    _status = CurriculumViewState.loading;
    notifyListeners();

    try {
      _semesters = await _semesterRepo.fetchSemestersForSubject(subjectId);
      if (_semesters.isNotEmpty) {
        _units = await _unitRepo.fetchUnitsForSemester(_semesters.first.id);
        if (_units.isNotEmpty) {
          _lessons = await _lessonRepo.fetchLessonsForUnit(_units.first.id);
        }
      }
      _status = CurriculumViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = CurriculumViewState.failure;
    } catch (e) {
      _failure = UnexpectedFailure(message: e.toString());
      _status = CurriculumViewState.failure;
    }
    notifyListeners();
  }

  Future<void> loadLessonsForUnit(String unitId) async {
    try {
      _lessons = await _lessonRepo.fetchLessonsForUnit(unitId);
      notifyListeners();
    } catch (e) {
      _failure = DatabaseFailure(message: e.toString());
      notifyListeners();
    }
  }
}

class SemesterViewModel extends ChangeNotifier {
  final ISemesterRepository _repository;
  CurriculumViewState _status = CurriculumViewState.initial;
  List<Semester> _semesters = [];
  Failure? _failure;

  SemesterViewModel(this._repository);

  CurriculumViewState get status => _status;
  List<Semester> get semesters => _semesters;
  Failure? get failure => _failure;

  Future<void> fetchSemesters(String subjectId) async {
    _status = CurriculumViewState.loading;
    notifyListeners();

    try {
      _semesters = await _repository.fetchSemestersForSubject(subjectId);
      _status = CurriculumViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = CurriculumViewState.failure;
    }
    notifyListeners();
  }

  Future<void> createSemester(Semester semester) async {
    _status = CurriculumViewState.submitting;
    notifyListeners();

    try {
      await _repository.createSemester(semester);
      await fetchSemesters(semester.subjectId);
    } on Failure catch (f) {
      _failure = f;
      _status = CurriculumViewState.failure;
      notifyListeners();
    }
  }
}

class UnitViewModel extends ChangeNotifier {
  final IUnitRepository _repository;
  CurriculumViewState _status = CurriculumViewState.initial;
  List<Unit> _units = [];
  Failure? _failure;

  UnitViewModel(this._repository);

  CurriculumViewState get status => _status;
  List<Unit> get units => _units;
  Failure? get failure => _failure;

  Future<void> fetchUnits(String semesterId) async {
    _status = CurriculumViewState.loading;
    notifyListeners();

    try {
      _units = await _repository.fetchUnitsForSemester(semesterId);
      _status = CurriculumViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = CurriculumViewState.failure;
    }
    notifyListeners();
  }

  Future<void> createUnit(Unit unit) async {
    _status = CurriculumViewState.submitting;
    notifyListeners();

    try {
      await _repository.createUnit(unit);
      await fetchUnits(unit.semesterId);
    } on Failure catch (f) {
      _failure = f;
      _status = CurriculumViewState.failure;
      notifyListeners();
    }
  }
}

class LessonManagementViewModel extends ChangeNotifier {
  final ILessonRepository _repository;
  CurriculumViewState _status = CurriculumViewState.initial;
  List<Lesson> _lessons = [];
  Failure? _failure;

  LessonManagementViewModel(this._repository);

  CurriculumViewState get status => _status;
  List<Lesson> get lessons => _lessons;
  Failure? get failure => _failure;

  Future<void> fetchLessons(String unitId) async {
    _status = CurriculumViewState.loading;
    notifyListeners();

    try {
      _lessons = await _repository.fetchLessonsForUnit(unitId);
      _status = CurriculumViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = CurriculumViewState.failure;
    }
    notifyListeners();
  }

  Future<void> createLesson(Lesson lesson) async {
    _status = CurriculumViewState.submitting;
    notifyListeners();

    try {
      await _repository.createLesson(lesson);
      await fetchLessons(lesson.unitId);
    } on Failure catch (f) {
      _failure = f;
      _status = CurriculumViewState.failure;
      notifyListeners();
    }
  }

  Future<void> publishLesson(
    String lessonId,
    String unitId, {
    bool publish = true,
  }) async {
    _status = CurriculumViewState.submitting;
    notifyListeners();

    try {
      await _repository.publishLesson(lessonId, publish: publish);
      await fetchLessons(unitId);
    } on Failure catch (f) {
      _failure = f;
      _status = CurriculumViewState.failure;
      notifyListeners();
    }
  }
}

class LessonResourceViewModel extends ChangeNotifier {
  final ILessonResourceRepository _repository;
  CurriculumViewState _status = CurriculumViewState.initial;
  List<LessonResource> _resources = [];
  String? _authorizedUrl;
  Failure? _failure;

  LessonResourceViewModel(this._repository);

  CurriculumViewState get status => _status;
  List<LessonResource> get resources => _resources;
  String? get authorizedUrl => _authorizedUrl;
  Failure? get failure => _failure;

  Future<void> fetchResources(String lessonId) async {
    _status = CurriculumViewState.loading;
    notifyListeners();

    try {
      _resources = await _repository.fetchResourcesForLesson(lessonId);
      _status = CurriculumViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = CurriculumViewState.failure;
    }
    notifyListeners();
  }

  Future<void> requestAuthorizedUrl(String resourceId) async {
    _status = CurriculumViewState.loading;
    notifyListeners();

    try {
      _authorizedUrl = await _repository.getAuthorizedAssetUrl(resourceId);
      _status = CurriculumViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = CurriculumViewState.failure;
    }
    notifyListeners();
  }
}

class LessonPlayerViewModel extends ChangeNotifier {
  final ILessonRepository _lessonRepo;
  final ILessonProgressRepository _progressRepo;

  CurriculumViewState _status = CurriculumViewState.initial;
  Lesson? _currentLesson;
  LessonProgress? _progress;
  int _lastPositionSeconds = 0;
  int _progressPercentage = 0;
  Failure? _failure;

  LessonPlayerViewModel(this._lessonRepo, this._progressRepo);

  CurriculumViewState get status => _status;
  Lesson? get currentLesson => _currentLesson;
  LessonProgress? get progress => _progress;
  int get lastPositionSeconds => _lastPositionSeconds;
  int get progressPercentage => _progressPercentage;
  Failure? get failure => _failure;

  Future<void> loadLesson(String lessonId) async {
    _status = CurriculumViewState.loading;
    notifyListeners();

    try {
      _currentLesson = await _lessonRepo.getLessonById(lessonId);
      _progress = await _progressRepo.fetchProgressForLesson(lessonId);

      if (_progress != null) {
        _lastPositionSeconds = _progress!.lastPositionSeconds;
        _progressPercentage = _progress!.progressPercentage;
      }
      _status = CurriculumViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = CurriculumViewState.failure;
    } catch (e) {
      _failure = UnexpectedFailure(message: e.toString());
      _status = CurriculumViewState.failure;
    }
    notifyListeners();
  }

  Future<void> updateLessonProgress({
    required String lessonId,
    required String status,
    required int progressPercentage,
    int positionSeconds = 0,
    int timeSpentSeconds = 10,
  }) async {
    try {
      await _progressRepo.updateProgress(
        lessonId: lessonId,
        status: status,
        progressPercentage: progressPercentage,
        lastPositionSeconds: positionSeconds,
        timeSpentSeconds: timeSpentSeconds,
      );

      _lastPositionSeconds = positionSeconds;
      _progressPercentage = progressPercentage;
      notifyListeners();
    } on Failure catch (f) {
      _failure = f;
      notifyListeners();
    }
  }
}
