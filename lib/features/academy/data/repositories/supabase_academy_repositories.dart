import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../../core/errors/failures.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/academy_models.dart';
import '../../domain/repositories/academy_repositories.dart';

class SupabaseStudentRepository implements IStudentRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseStudentRepository(this._wrapper);

  @override
  Future<PaginatedResult<Student>> fetchStudents({
    String? search,
    String? branchId,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'get_student_list',
        params: {
          'p_search': search,
          'p_branch_id': branchId,
          'p_status': status,
          'p_page': page,
          'p_page_size': pageSize,
        },
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      final total = jsonMap['total'] as int? ?? 0;
      final rawList = jsonMap['data'] as List<dynamic>? ?? [];
      final students = rawList
          .map((j) => Student.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();

      return PaginatedResult<Student>(
        total: total,
        page: page,
        pageSize: pageSize,
        data: students,
      );
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch students: ${e.toString()}',
      );
    }
  }

  @override
  Future<Student> getStudentById(String id) async {
    try {
      final response = await _wrapper.client
          .from('students')
          .select('*, profiles(*)')
          .eq('id', id)
          .single();

      final prof = response['profiles'] as Map<String, dynamic>;
      final merged = {
        ...response,
        'full_name': prof['full_name'],
        'email': prof['email'],
        'avatar_url': prof['avatar_url'],
        'phone_number': prof['phone_number'],
      };
      return Student.fromJson(merged);
    } catch (e) {
      throw DatabaseFailure(message: 'Student not found: ${e.toString()}');
    }
  }

  @override
  Future<Student> createStudent(Student student) async {
    try {
      final response = await _wrapper.client
          .from('students')
          .insert({
            'profile_id': student.profileId,
            'student_code': student.studentCode,
            'primary_branch_id': student.primaryBranchId,
            'grade_level': student.gradeLevel,
            'school_name': student.schoolName,
            'status': student.status,
          })
          .select('*, profiles(*)')
          .single();

      final prof = response['profiles'] as Map<String, dynamic>;
      final merged = {
        ...response,
        'full_name': prof['full_name'],
        'email': prof['email'],
      };
      return Student.fromJson(merged);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to create student: ${e.toString()}',
      );
    }
  }

  @override
  Future<Student> updateStudent(Student student) async {
    try {
      final response = await _wrapper.client
          .from('students')
          .update({
            'grade_level': student.gradeLevel,
            'school_name': student.schoolName,
            'status': student.status,
          })
          .eq('id', student.id)
          .select('*, profiles(*)')
          .single();

      final prof = response['profiles'] as Map<String, dynamic>;
      final merged = {
        ...response,
        'full_name': prof['full_name'],
        'email': prof['email'],
      };
      return Student.fromJson(merged);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to update student: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<Student>> fetchStudentsForGroup(String groupId) async {
    try {
      final response = await _wrapper.client.rpc(
        'get_group_students',
        params: {'p_group_id': groupId},
      );

      final rawList = response as List<dynamic>;
      return rawList
          .map((j) => Student.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch group roster: ${e.toString()}',
      );
    }
  }
}

class SupabaseParentRepository implements IParentRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseParentRepository(this._wrapper);

  @override
  Future<PaginatedResult<Parent>> fetchParents({
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'get_parent_list',
        params: {'p_search': search, 'p_page': page, 'p_page_size': pageSize},
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      final total = jsonMap['total'] as int? ?? 0;
      final rawList = jsonMap['data'] as List<dynamic>? ?? [];
      final parents = rawList
          .map((j) => Parent.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();

      return PaginatedResult<Parent>(
        total: total,
        page: page,
        pageSize: pageSize,
        data: parents,
      );
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch parents: ${e.toString()}',
      );
    }
  }

  @override
  Future<Parent> getParentById(String id) async {
    try {
      final response = await _wrapper.client
          .from('parents')
          .select('*, profiles(*)')
          .eq('id', id)
          .single();

      final prof = response['profiles'] as Map<String, dynamic>;
      final merged = {
        ...response,
        'full_name': prof['full_name'],
        'email': prof['email'],
      };
      return Parent.fromJson(merged);
    } catch (e) {
      throw DatabaseFailure(message: 'Parent not found: ${e.toString()}');
    }
  }

  @override
  Future<List<Student>> fetchLinkedStudents(String parentId) async {
    try {
      final links = await _wrapper.client
          .from('parent_students')
          .select('student_id')
          .eq('parent_id', parentId);
      final studentIds = (links as List)
          .map((l) => l['student_id'] as String)
          .toList();
      if (studentIds.isEmpty) return [];

      final studentsRaw = await _wrapper.client
          .from('students')
          .select('*, profiles(*)')
          .filter('id', 'in', studentIds);

      return (studentsRaw as List).map((s) {
        final Map<String, dynamic> item = Map<String, dynamic>.from(s as Map);
        final prof = Map<String, dynamic>.from(item['profiles'] as Map);
        return Student.fromJson({
          ...item,
          'full_name': prof['full_name'],
          'email': prof['email'],
        });
      }).toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch linked students: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> linkParentToStudent({
    required String parentId,
    required String studentId,
    String relationshipType = 'guardian',
    bool isPrimary = false,
  }) async {
    try {
      if (isPrimary) {
        await setPrimaryGuardian(
          parentId: parentId,
          studentId: studentId,
          relationshipType: relationshipType,
        );
      } else {
        await _wrapper.client.from('parent_students').upsert({
          'parent_id': parentId,
          'student_id': studentId,
          'relationship_type': relationshipType,
          'is_primary': false,
        });
      }
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to link parent to student: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> setPrimaryGuardian({
    required String parentId,
    required String studentId,
    String relationshipType = 'guardian',
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'set_primary_guardian',
        params: {
          'p_student_id': studentId,
          'p_parent_id': parentId,
          'p_relationship_type': relationshipType,
        },
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(
          message:
              jsonMap['message'] as String? ??
              'Setting primary guardian failed',
        );
      }
    } on supabase.PostgrestException catch (e) {
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Setting primary guardian failed: ${e.toString()}',
      );
    }
  }
}

class SupabaseTeacherRepository implements ITeacherRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseTeacherRepository(this._wrapper);

  @override
  Future<PaginatedResult<Teacher>> fetchTeachers({
    String? search,
    String? branchId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'get_teacher_list',
        params: {
          'p_search': search,
          'p_branch_id': branchId,
          'p_page': page,
          'p_page_size': pageSize,
        },
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      final total = jsonMap['total'] as int? ?? 0;
      final rawList = jsonMap['data'] as List<dynamic>? ?? [];
      final teachers = rawList
          .map((j) => Teacher.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();

      return PaginatedResult<Teacher>(
        total: total,
        page: page,
        pageSize: pageSize,
        data: teachers,
      );
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch teachers: ${e.toString()}',
      );
    }
  }

  @override
  Future<Teacher> getTeacherById(String id) async {
    try {
      final response = await _wrapper.client
          .from('teachers')
          .select('*, profiles(*)')
          .eq('id', id)
          .single();

      final prof = response['profiles'] as Map<String, dynamic>;
      final merged = {
        ...response,
        'full_name': prof['full_name'],
        'email': prof['email'],
      };
      return Teacher.fromJson(merged);
    } catch (e) {
      throw DatabaseFailure(message: 'Teacher not found: ${e.toString()}');
    }
  }

  @override
  Future<Teacher> updateTeacher(Teacher teacher) async {
    try {
      final response = await _wrapper.client
          .from('teachers')
          .update({
            'specialization': teacher.specialization,
            'bio': teacher.bio,
          })
          .eq('id', teacher.id)
          .select('*, profiles(*)')
          .single();

      final prof = response['profiles'] as Map<String, dynamic>;
      final merged = {
        ...response,
        'full_name': prof['full_name'],
        'email': prof['email'],
      };
      return Teacher.fromJson(merged);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to update teacher: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<GroupEntity>> fetchAssignedGroups(String teacherId) async {
    try {
      final groupsRaw = await _wrapper.client.rpc(
        'get_teacher_assigned_groups',
        params: {'p_teacher_id': teacherId},
      );

      return (groupsRaw as List)
          .map((g) => GroupEntity.fromJson(g as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch assigned groups: ${e.toString()}',
      );
    }
  }
}

class SupabaseBranchRepository implements IBranchRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseBranchRepository(this._wrapper);

  @override
  Future<List<Branch>> fetchBranches({
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      var query = _wrapper.client.from('branches').select();
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      if (search != null && search.isNotEmpty) {
        query = query.ilike('name', '%$search%');
      }
      final response = await query.order('name');
      return (response as List)
          .map((json) => Branch.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch branches: ${e.toString()}',
      );
    }
  }

  @override
  Future<Branch> getBranchById(String id) async {
    try {
      final response = await _wrapper.client
          .from('branches')
          .select()
          .eq('id', id)
          .single();
      return Branch.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(message: 'Branch not found: ${e.toString()}');
    }
  }

  @override
  Future<Branch> createBranch(Branch branch) async {
    try {
      final response = await _wrapper.client
          .from('branches')
          .insert(branch.toJson())
          .select()
          .single();
      return Branch.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to create branch: ${e.toString()}',
      );
    }
  }

  @override
  Future<Branch> updateBranch(Branch branch) async {
    try {
      final response = await _wrapper.client
          .from('branches')
          .update(branch.toJson())
          .eq('id', branch.id)
          .select()
          .single();
      return Branch.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to update branch: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> deleteBranch(String id) async {
    try {
      await _wrapper.client.rpc('delete_branch', params: {'branch_id': id});
    } catch (e) {
      throw DatabaseFailure(message: 'Failed to delete branch: ${e.toString()}');
    }
  }
}

class SupabaseSubjectRepository implements ISubjectRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseSubjectRepository(this._wrapper);

  @override
  Future<List<SubjectEntity>> fetchSubjects({
    String? search,
    String? status,
  }) async {
    try {
      var query = _wrapper.client.from('subjects').select();
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      if (search != null && search.isNotEmpty) {
        query = query.ilike('name', '%$search%');
      }
      final response = await query.order('name');
      return (response as List)
          .map((json) => SubjectEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch subjects: ${e.toString()}',
      );
    }
  }

  @override
  Future<SubjectEntity> createSubject(SubjectEntity subject) async {
    try {
      final response = await _wrapper.client
          .from('subjects')
          .insert(subject.toJson())
          .select()
          .single();
      return SubjectEntity.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to create subject: ${e.toString()}',
      );
    }
  }

  @override
  Future<SubjectEntity> updateSubject(SubjectEntity subject) async {
    try {
      final response = await _wrapper.client
          .from('subjects')
          .update(subject.toJson())
          .eq('id', subject.id)
          .select()
          .single();
      return SubjectEntity.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to update subject: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> deleteSubject(String id) async {
    try {
      await _wrapper.client.rpc('delete_subject', params: {'subject_id': id});
    } catch (e) {
      throw DatabaseFailure(message: 'Failed to delete subject: ${e.toString()}');
    }
  }
}

class SupabaseGroupRepository implements IGroupRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseGroupRepository(this._wrapper);

  @override
  Future<List<GroupEntity>> fetchGroups({
    String? branchId,
    String? subjectId,
    String? status,
  }) async {
    try {
      var query = _wrapper.client.from('groups').select();
      if (branchId != null) query = query.eq('branch_id', branchId);
      if (subjectId != null) query = query.eq('subject_id', subjectId);
      if (status != null) query = query.eq('status', status);

      final response = await query.order('name');
      return (response as List)
          .map((json) => GroupEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(message: 'Failed to fetch groups: ${e.toString()}');
    }
  }

  @override
  Future<GroupEntity> getGroupById(String id) async {
    try {
      final response = await _wrapper.client
          .from('groups')
          .select()
          .eq('id', id)
          .single();
      return GroupEntity.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(message: 'Group not found: ${e.toString()}');
    }
  }

  @override
  Future<GroupEntity> createGroup(GroupEntity group) async {
    try {
      final response = await _wrapper.client
          .from('groups')
          .insert(group.toJson())
          .select()
          .single();
      return GroupEntity.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(message: 'Failed to create group: ${e.toString()}');
    }
  }

  @override
  Future<GroupEntity> updateGroup(GroupEntity group) async {
    try {
      final response = await _wrapper.client
          .from('groups')
          .update(group.toJson())
          .eq('id', group.id)
          .select()
          .single();
      return GroupEntity.fromJson(response);
    } catch (e) {
      throw DatabaseFailure(message: 'Failed to update group: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteGroup(String id) async {
    try {
      await _wrapper.client.rpc('delete_group', params: {'group_id': id});
    } catch (e) {
      throw DatabaseFailure(message: 'Failed to delete group: ${e.toString()}');
    }
  }
}

class SupabaseEnrollmentRepository implements IEnrollmentRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseEnrollmentRepository(this._wrapper);

  Future<List<GroupEntity>> fetchGroupsForStudent(String studentId) async {
    try {
      final groupsRaw = await _wrapper.client.rpc(
        'get_student_groups',
        params: {'p_student_id': studentId},
      );

      return (groupsRaw as List)
          .map((g) => GroupEntity.fromJson(g as Map<String, dynamic>))
          .where((group) => group.id.isNotEmpty)
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch student groups: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<EnrollmentEntity>> fetchEnrollmentsForStudent(
    String studentId,
  ) async {
    try {
      final response = await _wrapper.client
          .from('enrollments')
          .select()
          .eq('student_id', studentId);
      return (response as List)
          .map(
            (json) => EnrollmentEntity.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch student enrollments: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> enrollStudentInGroup({
    required String studentId,
    required String groupId,
    int totalMinor = 0,
    int discountMinor = 0,
    String currency = 'EGP',
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'enroll_student_in_group',
        params: {
          'p_student_id': studentId,
          'p_group_id': groupId,
          'p_total_minor': totalMinor,
          'p_discount_minor': discountMinor,
          'p_currency': currency,
        },
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(
          message: jsonMap['message'] as String? ?? 'Enrollment failed',
        );
      }
    } on supabase.PostgrestException catch (e) {
      if (e.code == '54000') {
        throw DatabaseFailure(message: 'Group is full (capacity exceeded).');
      }
      if (e.code == '23505') {
        throw DatabaseFailure(
          message: 'Student is already enrolled in this group.',
        );
      }
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(message: 'Enrollment failed: ${e.toString()}');
    }
  }
}

class SupabaseScheduleRepository implements IScheduleRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseScheduleRepository(this._wrapper);

  @override
  Future<List<ScheduleEntity>> fetchSchedulesForGroup(String groupId) async {
    try {
      final response = await _wrapper.client
          .from('schedules')
          .select()
          .eq('group_id', groupId)
          .order('day_of_week');
      return (response as List)
          .map((json) => ScheduleEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch schedules: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> createSchedule({
    required String groupId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? roomLocation,
  }) async {
    try {
      final response = await _wrapper.client.rpc(
        'validate_and_create_schedule',
        params: {
          'p_group_id': groupId,
          'p_day_of_week': dayOfWeek,
          'p_start_time': startTime,
          'p_end_time': endTime,
          'p_room_location': roomLocation,
        },
      );

      final jsonMap = Map<String, dynamic>.from(response as Map);
      if (jsonMap['success'] != true) {
        throw DatabaseFailure(
          message: jsonMap['message'] as String? ?? 'Schedule creation failed',
        );
      }
    } on supabase.PostgrestException catch (e) {
      if (e.code == '23514') {
        throw DatabaseFailure(message: 'End time must be after start time.');
      }
      if (e.code == '23505') {
        throw DatabaseFailure(
          message:
              'Schedule conflict detected for group, teacher, or location.',
        );
      }
      throw DatabaseFailure(message: e.message);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Schedule creation failed: ${e.toString()}',
      );
    }
  }
}

class SupabaseAcademySummaryRepository implements IAcademySummaryRepository {
  final SupabaseClientWrapper _wrapper;
  SupabaseAcademySummaryRepository(this._wrapper);

  @override
  Future<AcademyCoreSummary> fetchSummary() async {
    try {
      final response = await _wrapper.client.rpc('get_academy_core_summary');
      final jsonMap = Map<String, dynamic>.from(response as Map);
      return AcademyCoreSummary.fromJson(jsonMap);
    } catch (e) {
      throw DatabaseFailure(
        message: 'Failed to fetch academy summary: ${e.toString()}',
      );
    }
  }
}
