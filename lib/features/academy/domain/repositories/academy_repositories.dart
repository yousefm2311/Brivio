import '../models/academy_models.dart';

abstract class IStudentRepository {
  Future<PaginatedResult<Student>> fetchStudents({
    String? search,
    String? branchId,
    String? status,
    int page = 1,
    int pageSize = 20,
  });
  Future<Student> getStudentById(String id);
  Future<Student> createStudent(Student student);
  Future<Student> updateStudent(Student student);
  Future<List<Student>> fetchStudentsForGroup(String groupId);
}

abstract class IParentRepository {
  Future<PaginatedResult<Parent>> fetchParents({
    String? search,
    int page = 1,
    int pageSize = 20,
  });
  Future<Parent> getParentById(String id);
  Future<List<Student>> fetchLinkedStudents(String parentId);
  Future<void> linkParentToStudent({
    required String parentId,
    required String studentId,
    String relationshipType = 'guardian',
    bool isPrimary = false,
  });
  Future<void> setPrimaryGuardian({
    required String parentId,
    required String studentId,
    String relationshipType = 'guardian',
  });
}

abstract class ITeacherRepository {
  Future<PaginatedResult<Teacher>> fetchTeachers({
    String? search,
    String? branchId,
    int page = 1,
    int pageSize = 20,
  });
  Future<Teacher> getTeacherById(String id);
  Future<Teacher> updateTeacher(Teacher teacher);
  Future<List<GroupEntity>> fetchAssignedGroups(String teacherId);
}

abstract class IBranchRepository {
  Future<List<Branch>> fetchBranches({
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
  });
  Future<Branch> getBranchById(String id);
  Future<Branch> createBranch(Branch branch);
  Future<Branch> updateBranch(Branch branch);
  Future<void> deleteBranch(String id);
}

abstract class ISubjectRepository {
  Future<List<SubjectEntity>> fetchSubjects({String? search, String? status});
  Future<SubjectEntity> createSubject(SubjectEntity subject);
  Future<SubjectEntity> updateSubject(SubjectEntity subject);
  Future<void> deleteSubject(String id);
}

abstract class IGroupRepository {
  Future<List<GroupEntity>> fetchGroups({
    String? branchId,
    String? subjectId,
    String? status,
  });
  Future<GroupEntity> getGroupById(String id);
  Future<GroupEntity> createGroup(GroupEntity group);
  Future<GroupEntity> updateGroup(GroupEntity group);
  Future<void> deleteGroup(String id);
}

abstract class IEnrollmentRepository {
  Future<List<EnrollmentEntity>> fetchEnrollmentsForStudent(String studentId);
  Future<void> enrollStudentInGroup({
    required String studentId,
    required String groupId,
    int totalMinor = 0,
    int discountMinor = 0,
    String currency = 'EGP',
  });
}

abstract class IScheduleRepository {
  Future<List<ScheduleEntity>> fetchSchedulesForGroup(String groupId);
  Future<void> createSchedule({
    required String groupId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? roomLocation,
  });
}

abstract class IAcademySummaryRepository {
  Future<AcademyCoreSummary> fetchSummary();
}
