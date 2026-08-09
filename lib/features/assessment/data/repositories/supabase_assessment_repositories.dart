import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../../core/errors/failures.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/assessment_models.dart';
import '../../domain/repositories/assessment_repositories.dart';

class SupabaseQuestionBankRepository implements IQuestionBankRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseQuestionBankRepository(this._wrapper);

  @override
  Future<List<Question>> fetchQuestionsForSubject(String subjectId) async {
    try {
      final response = await _wrapper.client
          .from('questions')
          .select('*, student_question_options(*)')
          .eq('subject_id', subjectId)
          .order('created_at', ascending: false);

      return (response as List).map((j) {
        final item = Map<String, dynamic>.from(j as Map);
        final rawOpts =
            item['student_question_options'] as List<dynamic>? ?? [];
        final opts = rawOpts
            .map(
              (o) =>
                  QuestionOption.fromJson(Map<String, dynamic>.from(o as Map)),
            )
            .toList();
        return Question.fromJson(item, opts);
      }).toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch question bank: ${e.toString()}',
      );
    }
  }

  @override
  Future<Question> createQuestion(
    Question question,
    List<QuestionOption> options,
  ) async {
    try {
      final response = await _wrapper.client.rpc(
        'create_question_with_options',
        params: {
          'p_subject_id': question.subjectId,
          'p_unit_id': question.unitId,
          'p_lesson_id': question.lessonId,
          'p_question_type': question.questionType.toDbValue(),
          'p_prompt': question.prompt,
          'p_explanation': question.explanation,
          'p_difficulty': question.difficulty,
          'p_default_points': question.defaultPoints,
          'p_options': [
            for (int i = 0; i < options.length; i++)
              {
                'text': options[i].text,
                'order_number': i + 1,
                'is_correct': options[i].isCorrect,
              },
          ],
        },
      );

      final qRes = Map<String, dynamic>.from(response as Map);
      final rawOpts = qRes['student_question_options'] as List<dynamic>? ?? [];
      final createdOpts = rawOpts
          .map(
            (o) => QuestionOption.fromJson(Map<String, dynamic>.from(o as Map)),
          )
          .toList();

      return Question.fromJson(qRes, createdOpts);
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: 'Failed to create question: ${e.message}');
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to create question: ${e.toString()}',
      );
    }
  }
}

class SupabaseHomeworkRepository implements IHomeworkRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseHomeworkRepository(this._wrapper);

  @override
  Future<List<Homework>> fetchHomeworkForGroup(String groupId) async {
    try {
      final response = await _wrapper.client
          .from('homework')
          .select()
          .eq('group_id', groupId)
          .order('due_at');
      return (response as List)
          .map((j) => Homework.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch homework: ${e.toString()}',
      );
    }
  }

  @override
  Future<Homework> createHomework(Homework homework) async {
    try {
      final response = await _wrapper.client.rpc(
        'create_homework_assignment',
        params: {
          'p_title': homework.title,
          'p_description': homework.description,
          'p_subject_id': homework.subjectId,
          'p_group_id': homework.groupId,
          'p_due_at': homework.dueAt.toIso8601String(),
          'p_max_score': homework.maxScore,
          'p_status': homework.status,
        },
      );
      return Homework.fromJson(Map<String, dynamic>.from(response as Map));
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: 'Failed to create homework: ${e.message}');
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to create homework: ${e.toString()}',
      );
    }
  }
}

class SupabaseExamRepository implements IExamRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseExamRepository(this._wrapper);

  @override
  Future<List<Exam>> fetchExamsForGroup(String groupId) async {
    try {
      final response = await _wrapper.client
          .from('exams')
          .select(
            '*, exam_questions(*, questions(*, student_question_options(*)))',
          )
          .eq('group_id', groupId)
          .order('created_at', ascending: false);

      return (response as List).map((j) {
        final item = Map<String, dynamic>.from(j as Map);
        final rawEqs = item['exam_questions'] as List<dynamic>? ?? [];
        final qList = rawEqs.map((eq) {
          final eqMap = Map<String, dynamic>.from(eq as Map);
          final qMap = Map<String, dynamic>.from(eqMap['questions'] as Map);
          final rawOpts =
              qMap['student_question_options'] as List<dynamic>? ?? [];
          final opts = rawOpts
              .map(
                (o) => QuestionOption.fromJson(
                  Map<String, dynamic>.from(o as Map),
                ),
              )
              .toList();
          return Question.fromJson(qMap, opts);
        }).toList();
        return Exam.fromJson(item, qList);
      }).toList();
    } catch (e) {
      throw DatabaseFailure(message: 'Failed to fetch exams: ${e.toString()}');
    }
  }

  @override
  Future<ExamAttempt> startExam(String examId) async {
    try {
      final response = await _wrapper.client.rpc(
        'start_exam',
        params: {'p_exam_id': examId},
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(message: 'Failed to start exam');
      }

      final attemptId = jsonMap['attempt_id'] as String;

      final attemptRes = await _wrapper.client
          .from('exam_attempts')
          .select()
          .eq('id', attemptId)
          .single();

      return ExamAttempt.fromJson(attemptRes);
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(message: 'Start exam failed: ${e.toString()}');
    }
  }

  @override
  Future<void> saveExamAnswer({
    required String attemptId,
    required String questionId,
    String? selectedOptionId,
    String? textAnswer,
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'save_exam_answer',
        params: {
          'p_attempt_id': attemptId,
          'p_question_id': questionId,
          'p_selected_option_id': selectedOptionId,
          'p_text_answer': textAnswer,
        },
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(message: 'Save exam answer failed');
      }
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(message: 'Save answer failed: ${e.toString()}');
    }
  }

  @override
  Future<ExamAttempt> submitExamAttempt(String attemptId) async {
    try {
      final response = await _wrapper.client.rpc(
        'submit_exam_attempt',
        params: {'p_attempt_id': attemptId},
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(message: 'Submit exam attempt failed');
      }

      final attemptRes = await _wrapper.client
          .from('exam_attempts')
          .select()
          .eq('id', attemptId)
          .single();

      return ExamAttempt.fromJson(attemptRes);
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(message: 'Submit attempt failed: ${e.toString()}');
    }
  }
}
