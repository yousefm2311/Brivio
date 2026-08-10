import '../models/assessment_models.dart';

abstract class IQuestionBankRepository {
  Future<List<Question>> fetchQuestionsForSubject(String subjectId);
  Future<Question> createQuestion(
    Question question,
    List<QuestionOption> options,
  );
  Future<void> updateQuestion(
    Question question,
    List<QuestionOption> options,
  );
}

abstract class IHomeworkRepository {
  Future<List<Homework>> fetchHomeworkForGroup(String groupId);
  Future<Homework> createHomework(Homework homework);
  Future<void> linkQuestion(String homeworkId, String questionId, double points);
  Future<void> unlinkQuestion(String homeworkId, String questionId);
}

abstract class IExamRepository {
  Future<List<Exam>> fetchExamsForGroup(String groupId);
  Future<ExamAttempt> startExam(String examId);
  Future<void> saveExamAnswer({
    required String attemptId,
    required String questionId,
    String? selectedOptionId,
    String? textAnswer,
  });
  Future<ExamAttempt> submitExamAttempt(String attemptId);
  Future<void> linkQuestion(String examId, String questionId, double points);
  Future<void> unlinkQuestion(String examId, String questionId);
}
