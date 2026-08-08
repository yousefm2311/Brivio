/// Typed Granular Permission Catalog matching Database Permission Codes
enum Permission {
  studentsView('students.view'),
  studentsCreate('students.create'),
  studentsUpdate('students.update'),
  studentsDelete('students.delete'),
  parentsView('parents.view'),
  groupsView('groups.view'),
  groupsCreate('groups.create'),
  enrollmentsView('enrollments.view'),
  curriculumView('curriculum.view'),
  curriculumPublish('curriculum.publish');

  final String code;
  const Permission(this.code);

  static Permission? fromCode(String code) {
    for (final p in Permission.values) {
      if (p.code == code) return p;
    }
    return null;
  }
}
