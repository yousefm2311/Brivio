import 'package:equatable/equatable.dart';

class PaginatedResult<T> extends Equatable {
  final int total;
  final int page;
  final int pageSize;
  final List<T> data;

  const PaginatedResult({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.data,
  });

  @override
  List<Object?> get props => [total, page, pageSize, data];
}

class Student extends Equatable {
  final String id;
  final String profileId;
  final String studentCode;
  final String primaryBranchId;
  final String? gradeLevel;
  final String? schoolName;
  final String status;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final String? phoneNumber;

  const Student({
    required this.id,
    required this.profileId,
    required this.studentCode,
    required this.primaryBranchId,
    this.gradeLevel,
    this.schoolName,
    required this.status,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    this.phoneNumber,
  });

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: json['id'] as String? ?? '',
    profileId: json['profile_id'] as String? ?? '',
    studentCode: json['student_code'] as String? ?? '',
    primaryBranchId: json['primary_branch_id'] as String? ?? '',
    gradeLevel: json['grade_level'] as String?,
    schoolName: json['school_name'] as String?,
    status: json['status'] as String? ?? 'active',
    fullName: json['full_name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    phoneNumber: json['phone_number'] as String?,
  );

  @override
  List<Object?> get props => [
    id,
    profileId,
    studentCode,
    primaryBranchId,
    gradeLevel,
    schoolName,
    status,
    fullName,
    email,
    avatarUrl,
    phoneNumber,
  ];
}

class Parent extends Equatable {
  final String id;
  final String profileId;
  final String? occupation;
  final String status;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final String? phoneNumber;

  const Parent({
    required this.id,
    required this.profileId,
    this.occupation,
    required this.status,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    this.phoneNumber,
  });

  factory Parent.fromJson(Map<String, dynamic> json) => Parent(
    id: json['id'] as String? ?? '',
    profileId: json['profile_id'] as String? ?? '',
    occupation: json['occupation'] as String?,
    status: json['status'] as String? ?? 'active',
    fullName: json['full_name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    phoneNumber: json['phone_number'] as String?,
  );

  @override
  List<Object?> get props => [
    id,
    profileId,
    occupation,
    status,
    fullName,
    email,
    avatarUrl,
    phoneNumber,
  ];
}

class Teacher extends Equatable {
  final String id;
  final String profileId;
  final String primaryBranchId;
  final String? specialization;
  final String? bio;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final String? phoneNumber;
  final String? status;

  const Teacher({
    required this.id,
    required this.profileId,
    required this.primaryBranchId,
    this.specialization,
    this.bio,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    this.phoneNumber,
    this.status,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) => Teacher(
    id: json['id'] as String? ?? '',
    profileId: json['profile_id'] as String? ?? '',
    primaryBranchId: json['primary_branch_id'] as String? ?? '',
    specialization: json['specialization'] as String?,
    bio: json['bio'] as String?,
    fullName: json['full_name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    phoneNumber: json['phone_number'] as String?,
    status: json['status'] as String? ?? 'active',
  );

  @override
  List<Object?> get props => [
    id,
    profileId,
    primaryBranchId,
    specialization,
    bio,
    fullName,
    email,
    avatarUrl,
    phoneNumber,
    status,
  ];
}

class ParentStudentLink extends Equatable {
  final String parentId;
  final String studentId;
  final String relationshipType;
  final bool isPrimary;

  const ParentStudentLink({
    required this.parentId,
    required this.studentId,
    required this.relationshipType,
    required this.isPrimary,
  });

  factory ParentStudentLink.fromJson(Map<String, dynamic> json) =>
      ParentStudentLink(
        parentId: json['parent_id'] as String,
        studentId: json['student_id'] as String,
        relationshipType: json['relationship_type'] as String? ?? 'guardian',
        isPrimary: json['is_primary'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [parentId, studentId, relationshipType, isPrimary];
}

class Branch extends Equatable {
  final String id;
  final String name;
  final String code;
  final String? address;
  final String? phoneNumber;
  final String status;

  const Branch({
    required this.id,
    required this.name,
    required this.code,
    this.address,
    this.phoneNumber,
    required this.status,
  });

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    id: json['id'] as String,
    name: json['name'] as String,
    code: json['code'] as String,
    address: json['address'] as String?,
    phoneNumber: json['phone_number'] as String?,
    status: json['status'] as String? ?? 'active',
  );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'code': code,
      'address': address,
      'phone_number': phoneNumber,
      'status': status,
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }

  @override
  List<Object?> get props => [id, name, code, address, phoneNumber, status];
}

class SubjectEntity extends Equatable {
  final String id;
  final String name;
  final String code;
  final String? description;
  final String status;

  const SubjectEntity({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    required this.status,
  });

  factory SubjectEntity.fromJson(Map<String, dynamic> json) => SubjectEntity(
    id: json['id'] as String,
    name: json['name'] as String,
    code: json['code'] as String,
    description: json['description'] as String?,
    status: json['status'] as String? ?? 'active',
  );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'code': code,
      'description': description,
      'status': status,
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }

  @override
  List<Object?> get props => [id, name, code, description, status];
}

class GroupEntity extends Equatable {
  final String id;
  final String name;
  final String code;
  final String subjectId;
  final String branchId;
  final int? maxCapacity;
  final String status;

  const GroupEntity({
    required this.id,
    required this.name,
    required this.code,
    required this.subjectId,
    required this.branchId,
    this.maxCapacity,
    required this.status,
  });

  factory GroupEntity.fromJson(Map<String, dynamic> json) => GroupEntity(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Group',
    code: json['code'] as String? ?? '',
    subjectId: json['subject_id'] as String? ?? '',
    branchId: json['branch_id'] as String? ?? '',
    maxCapacity: json['max_capacity'] as int?,
    status: json['status'] as String? ?? 'active',
  );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'code': code,
      'subject_id': subjectId,
      'branch_id': branchId,
      'max_capacity': maxCapacity,
      'status': status,
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    code,
    subjectId,
    branchId,
    maxCapacity,
    status,
  ];
}

class EnrollmentEntity extends Equatable {
  final String id;
  final String studentId;
  final String groupId;
  final String status;
  final DateTime enrolledAt;

  const EnrollmentEntity({
    required this.id,
    required this.studentId,
    required this.groupId,
    required this.status,
    required this.enrolledAt,
  });

  factory EnrollmentEntity.fromJson(Map<String, dynamic> json) =>
      EnrollmentEntity(
        id: json['id'] as String? ?? '',
        studentId: json['student_id'] as String? ?? '',
        groupId: json['group_id'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
        enrolledAt:
            DateTime.tryParse(
              json['enrolled_at'] as String? ??
                  json['start_date'] as String? ??
                  '',
            ) ??
            DateTime.now(),
      );

  @override
  List<Object?> get props => [id, studentId, groupId, status, enrolledAt];
}

class ScheduleEntity extends Equatable {
  final String id;
  final String groupId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? roomLocation;
  final String status;

  const ScheduleEntity({
    required this.id,
    required this.groupId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.roomLocation,
    required this.status,
  });

  factory ScheduleEntity.fromJson(Map<String, dynamic> json) => ScheduleEntity(
    id: json['id'] as String,
    groupId: json['group_id'] as String,
    dayOfWeek: json['day_of_week'] as int,
    startTime: json['start_time'] as String,
    endTime: json['end_time'] as String,
    roomLocation: json['room_location'] as String?,
    status: json['status'] as String? ?? 'active',
  );

  @override
  List<Object?> get props => [
    id,
    groupId,
    dayOfWeek,
    startTime,
    endTime,
    roomLocation,
    status,
  ];
}

class AcademyCoreSummary extends Equatable {
  final int activeBranches;
  final int activeStudents;
  final int activeTeachers;
  final int activeSubjects;
  final int activeGroups;
  final int todayScheduledClasses;

  const AcademyCoreSummary({
    required this.activeBranches,
    required this.activeStudents,
    required this.activeTeachers,
    required this.activeSubjects,
    required this.activeGroups,
    required this.todayScheduledClasses,
  });

  factory AcademyCoreSummary.fromJson(Map<String, dynamic> json) =>
      AcademyCoreSummary(
        activeBranches: json['active_branches'] as int? ?? 0,
        activeStudents: json['active_students'] as int? ?? 0,
        activeTeachers: json['active_teachers'] as int? ?? 0,
        activeSubjects: json['active_subjects'] as int? ?? 0,
        activeGroups: json['active_groups'] as int? ?? 0,
        todayScheduledClasses: json['today_scheduled_classes'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [
    activeBranches,
    activeStudents,
    activeTeachers,
    activeSubjects,
    activeGroups,
    todayScheduledClasses,
  ];
}
