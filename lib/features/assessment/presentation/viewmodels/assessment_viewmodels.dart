import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/models/assessment_models.dart';
import '../../domain/repositories/assessment_repositories.dart';

enum AssessmentViewState {
  initial,
  loading,
  loaded,
  submitting,
  active,
  submitted,
  failure,
}

class QuestionBankViewModel extends ChangeNotifier {
  final IQuestionBankRepository _repository;
  AssessmentViewState _status = AssessmentViewState.initial;
  List<Question> _questions = [];
  Failure? _failure;

  QuestionBankViewModel(this._repository);

  AssessmentViewState get status => _status;
  List<Question> get questions => _questions;
  Failure? get failure => _failure;

  Future<void> fetchQuestions(String subjectId) async {
    _status = AssessmentViewState.loading;
    notifyListeners();

    try {
      _questions = await _repository.fetchQuestionsForSubject(subjectId);
      _status = AssessmentViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = AssessmentViewState.failure;
    }
    notifyListeners();
  }

  Future<void> createQuestion(
    Question question,
    List<QuestionOption> options,
  ) async {
    _status = AssessmentViewState.submitting;
    notifyListeners();

    try {
      await _repository.createQuestion(question, options);
      await fetchQuestions(question.subjectId);
    } on Failure catch (f) {
      _failure = f;
      _status = AssessmentViewState.failure;
      notifyListeners();
    }
  }
}

class HomeworkViewModel extends ChangeNotifier {
  final IHomeworkRepository _repository;
  AssessmentViewState _status = AssessmentViewState.initial;
  List<Homework> _homeworkList = [];
  Failure? _failure;

  HomeworkViewModel(this._repository);

  AssessmentViewState get status => _status;
  List<Homework> get homeworkList => _homeworkList;
  Failure? get failure => _failure;

  Future<void> fetchHomework(String groupId) async {
    _status = AssessmentViewState.loading;
    notifyListeners();

    try {
      _homeworkList = await _repository.fetchHomeworkForGroup(groupId);
      _status = AssessmentViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = AssessmentViewState.failure;
    }
    notifyListeners();
  }

  Future<void> createHomework(Homework homework) async {
    _status = AssessmentViewState.submitting;
    notifyListeners();

    try {
      await _repository.createHomework(homework);
      if (homework.groupId != null) {
        await fetchHomework(homework.groupId!);
      }
    } on Failure catch (f) {
      _failure = f;
      _status = AssessmentViewState.failure;
      notifyListeners();
    }
  }
}

class ExamViewModel extends ChangeNotifier {
  final IExamRepository _repository;
  AssessmentViewState _status = AssessmentViewState.initial;
  List<Exam> _exams = [];
  Failure? _failure;

  ExamViewModel(this._repository);

  AssessmentViewState get status => _status;
  List<Exam> get exams => _exams;
  Failure? get failure => _failure;

  Future<void> fetchExams(String groupId) async {
    _status = AssessmentViewState.loading;
    notifyListeners();

    try {
      _exams = await _repository.fetchExamsForGroup(groupId);
      _status = AssessmentViewState.loaded;
    } on Failure catch (f) {
      _failure = f;
      _status = AssessmentViewState.failure;
    }
    notifyListeners();
  }
}

class ExamAttemptViewModel extends ChangeNotifier {
  final IExamRepository _repository;

  AssessmentViewState _status = AssessmentViewState.initial;
  Exam? _exam;
  ExamAttempt? _currentAttempt;
  final Map<String, String> _selectedOptions = {}; // question_id -> option_id
  final Map<String, String> _textAnswers = {}; // question_id -> text
  Failure? _failure;

  ExamAttemptViewModel(this._repository);

  AssessmentViewState get status => _status;
  Exam? get exam => _exam;
  ExamAttempt? get currentAttempt => _currentAttempt;
  Map<String, String> get selectedOptions => _selectedOptions;
  Map<String, String> get textAnswers => _textAnswers;
  Failure? get failure => _failure;

  Future<void> startExam(Exam exam) async {
    _exam = exam;
    _status = AssessmentViewState.loading;
    notifyListeners();

    try {
      _currentAttempt = await _repository.startExam(exam.id);
      _status = AssessmentViewState.active;
    } on Failure catch (f) {
      _failure = f;
      _status = AssessmentViewState.failure;
    } catch (e) {
      _failure = UnexpectedFailure(message: e.toString());
      _status = AssessmentViewState.failure;
    }
    notifyListeners();
  }

  Future<void> selectAnswer(String questionId, String optionId) async {
    _selectedOptions[questionId] = optionId;
    notifyListeners();

    if (_currentAttempt != null) {
      try {
        await _repository.saveExamAnswer(
          attemptId: _currentAttempt!.id,
          questionId: questionId,
          selectedOptionId: optionId,
        );
      } catch (e) {
        // Silently preserve local answer until reconnect/retry
      }
    }
  }

  Future<void> submitExam() async {
    if (_currentAttempt == null) return;
    _status = AssessmentViewState.submitting;
    notifyListeners();

    try {
      _currentAttempt = await _repository.submitExamAttempt(
        _currentAttempt!.id,
      );
      _status = AssessmentViewState.submitted;
    } on Failure catch (f) {
      _failure = f;
      _status = AssessmentViewState.failure;
    } catch (e) {
      _failure = UnexpectedFailure(message: e.toString());
      _status = AssessmentViewState.failure;
    }
    notifyListeners();
  }
}
