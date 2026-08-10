import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/models/academy_models.dart';

class StudentListWidget extends StatelessWidget {
  final List<Student> students;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onRefresh;
  final ValueChanged<Student>? onStudentSelected;

  const StudentListWidget({
    super.key,
    required this.students,
    this.isLoading = false,
    this.errorMessage,
    this.onSearchChanged,
    this.onRefresh,
    this.onStudentSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: context.tr(
                      'Search Students (Name, Code, Email)',
                    ),
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(icon: const Icon(Icons.refresh), onPressed: onRefresh),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (errorMessage != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Error: $errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          else if (students.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(context.tr('No students found.')),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final s = students[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      onTap: onStudentSelected != null
                          ? () => onStudentSelected!(s)
                          : null,
                      leading: CircleAvatar(
                        child: Text(
                          s.fullName.isNotEmpty
                              ? s.fullName[0].toUpperCase()
                              : 'S',
                        ),
                      ),
                      title: Text(
                        s.fullName.isNotEmpty
                            ? s.fullName
                            : '${context.tr('Student Code')}: ${s.studentCode}',
                      ),
                      subtitle: Text(
                        '${s.studentCode} | ${s.email} | ${context.tr('Grade')}: ${s.gradeLevel ?? context.tr("N/A")}',
                      ),
                      trailing: Chip(
                        label: Text(s.status),
                        backgroundColor: s.status == 'active'
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class ParentListWidget extends StatelessWidget {
  final List<Parent> parents;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<Parent>? onParentSelected;

  const ParentListWidget({
    super.key,
    required this.parents,
    this.isLoading = false,
    this.errorMessage,
    this.onSearchChanged,
    this.onParentSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: context.tr('Search Parents (Name, Email, Phone)'),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (parents.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(context.tr('No parents found.')),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: parents.length,
                itemBuilder: (context, index) {
                  final p = parents[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      onTap: onParentSelected != null
                          ? () => onParentSelected!(p)
                          : null,
                      leading: CircleAvatar(
                        child: Text(
                          p.fullName.isNotEmpty
                              ? p.fullName[0].toUpperCase()
                              : 'P',
                        ),
                      ),
                      title: Text(
                        p.fullName.isNotEmpty
                            ? p.fullName
                            : context.tr('Parent Record'),
                      ),
                      subtitle: Text(
                        '${p.email} | ${context.tr('Occupation')}: ${p.occupation ?? context.tr("N/A")}',
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class TeacherListWidget extends StatelessWidget {
  final List<Teacher> teachers;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<Teacher>? onTeacherSelected;

  const TeacherListWidget({
    super.key,
    required this.teachers,
    this.isLoading = false,
    this.errorMessage,
    this.onTeacherSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (teachers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(context.tr('No teachers found.')),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: teachers.length,
                itemBuilder: (context, index) {
                  final t = teachers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      onTap: onTeacherSelected != null
                          ? () => onTeacherSelected!(t)
                          : null,
                      leading: CircleAvatar(
                        child: Text(
                          t.fullName.isNotEmpty
                              ? t.fullName[0].toUpperCase()
                              : 'T',
                        ),
                      ),
                      title: Text(
                        t.fullName.isNotEmpty
                            ? t.fullName
                            : context.tr('Teacher Record'),
                      ),
                      subtitle: Text(
                        '${context.tr('Specialization')}: ${t.specialization ?? context.tr("General")} | ${t.email}',
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class GroupListWidget extends StatelessWidget {
  final List<GroupEntity> groups;
  final bool isLoading;
  final ValueChanged<GroupEntity>? onGroupSelected;

  const GroupListWidget({
    super.key,
    required this.groups,
    this.isLoading = false,
    this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (groups.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(context.tr('No active groups found.')),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final g = groups[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      onTap: onGroupSelected != null
                          ? () => onGroupSelected!(g)
                          : null,
                      leading: const Icon(Icons.group_work, color: Colors.blue),
                      title: Text('${g.name} (${g.code})'),
                      subtitle: Text(
                        '${context.tr('Max Capacity')}: ${g.maxCapacity ?? context.tr("Unlimited")}',
                      ),
                      trailing: Chip(
                        label: Text(g.status),
                        backgroundColor: g.status == 'active'
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class BranchListWidget extends StatelessWidget {
  final List<Branch> branches;
  final bool isLoading;
  final ValueChanged<Branch>? onBranchSelected;

  const BranchListWidget({
    super.key,
    required this.branches,
    this.isLoading = false,
    this.onBranchSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (branches.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(context.tr('No active branches found.')),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: branches.length,
                itemBuilder: (context, index) {
                  final b = branches[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      onTap: onBranchSelected != null
                          ? () => onBranchSelected!(b)
                          : null,
                      leading: const Icon(Icons.domain, color: Colors.indigo),
                      title: Text('${b.name} (${b.code})'),
                      subtitle: Text(
                        b.address ?? context.tr('No address provided'),
                      ),
                      trailing: Chip(
                        label: Text(b.status),
                        backgroundColor: b.status == 'active'
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class SubjectListWidget extends StatelessWidget {
  final List<SubjectEntity> subjects;
  final bool isLoading;
  final ValueChanged<SubjectEntity>? onSubjectSelected;

  const SubjectListWidget({
    super.key,
    required this.subjects,
    this.isLoading = false,
    this.onSubjectSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (subjects.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(context.tr('No active subjects found.')),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final s = subjects[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      onTap: onSubjectSelected != null
                          ? () => onSubjectSelected!(s)
                          : null,
                      leading: const Icon(Icons.book, color: Colors.deepOrange),
                      title: Text('${s.name} (${s.code})'),
                      subtitle: Text(
                        s.description ?? context.tr('No description'),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class ScheduleListWidget extends StatelessWidget {
  final List<ScheduleEntity> schedules;
  final bool isLoading;

  const ScheduleListWidget({
    super.key,
    required this.schedules,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (schedules.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(context.tr('No active schedules found.')),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: schedules.length,
                itemBuilder: (context, index) {
                  final sc = schedules[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      leading: const Icon(Icons.schedule, color: Colors.teal),
                      title: Text(
                        '${context.tr('Day')} ${sc.dayOfWeek}: ${sc.startTime} - ${sc.endTime}',
                      ),
                      subtitle: Text(
                        '${context.tr('Location')}: ${sc.roomLocation ?? context.tr("Unassigned Room")}',
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Details Dialog helper for Academy Core entities
class EntityDetailsDialog extends StatelessWidget {
  final String title;
  final Map<String, String> details;

  const EntityDetailsDialog({
    super.key,
    required this.title,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.t(title)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: details.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${context.l10n.t(e.key)}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: Text(context.l10n.t(e.value))),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Close')),
        ),
      ],
    );
  }
}
