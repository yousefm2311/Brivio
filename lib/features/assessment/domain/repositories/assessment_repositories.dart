import '../models/assessment_models.dart';

abstract class IQuestionBankRepository {
  Future<List<Question>> fetchQuestionsForSubject(String subjectId);
  Future<Question> createQuestion(
    Question question,
    List<QuestionOption> options,
  );
}

abstract class IHomeworkRepository {
  Future<List<Homework>> fetchHomeworkForGroup(String groupId);
  Future<Homework> createHomework(Homework homework);
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
}
