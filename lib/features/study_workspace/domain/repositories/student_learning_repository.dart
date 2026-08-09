import '../models/study_workspace_models.dart';

abstract class IStudentLearningRepository {
  Future<StudentLearningSnapshot> fetchSnapshotForStudent(String studentId);
}
