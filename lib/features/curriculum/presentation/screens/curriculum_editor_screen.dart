import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_curriculum_repositories.dart';
import '../../domain/models/curriculum_models.dart';

class CurriculumEditorScreen extends StatefulWidget {
  const CurriculumEditorScreen({super.key});

  @override
  State<CurriculumEditorScreen> createState() => _CurriculumEditorScreenState();
}

class _CurriculumEditorScreenState extends State<CurriculumEditorScreen> {
  late final SupabaseSemesterRepository _semesterRepo;
  late final SupabaseUnitRepository _unitRepo;
  late final SupabaseLessonRepository _lessonRepo;
  late final SupabaseLessonResourceRepository _resourceRepo;
  late final SupabaseSubjectRepository _subjectRepo;

  List<SubjectEntity> _subjects = [];
  SubjectEntity? _selectedSubject;
  List<Semester> _semesters = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _semesterRepo = SupabaseSemesterRepository(wrapper);
    _unitRepo = SupabaseUnitRepository(wrapper);
    _lessonRepo = SupabaseLessonRepository(wrapper);
    _resourceRepo = SupabaseLessonResourceRepository(wrapper);
    _subjectRepo = SupabaseSubjectRepository(wrapper);
    _loadCurriculum();
  }

  Future<void> _loadCurriculum() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final subjects = await _subjectRepo.fetchSubjects(status: 'active');
      final selected =
          _selectedSubject ?? (subjects.isEmpty ? null : subjects.first);
      final sList = selected == null
          ? <Semester>[]
          : await _semesterRepo.fetchSemestersForSubject(selected.id);
      final List<Semester> populatedSemesters = [];

      for (final sem in sList) {
        final uList = await _unitRepo.fetchUnitsForSemester(sem.id);
        final List<Unit> populatedUnits = [];

        for (final unit in uList) {
          final lList = await _lessonRepo.fetchLessonsForUnit(unit.id);
          populatedUnits.add(
            Unit(
              id: unit.id,
              semesterId: unit.semesterId,
              name: unit.name,
              code: unit.code,
              orderNumber: unit.orderNumber,
              status: unit.status,
              lessons: lList,
            ),
          );
        }

        populatedSemesters.add(
          Semester(
            id: sem.id,
            subjectId: sem.subjectId,
            name: sem.name,
            code: sem.code,
            orderNumber: sem.orderNumber,
            startDate: sem.startDate,
            endDate: sem.endDate,
            status: sem.status,
            units: populatedUnits,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _subjects = subjects;
          _selectedSubject = selected;
          _semesters = populatedSemesters;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showCreateSemesterDialog() {
    final selectedSubject = _selectedSubject;
    if (selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Create an active subject first.'))),
      );
      return;
    }
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Create Semester')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Semester Name (e.g. Fall 2026)'),
              ),
            ),
            TextField(
              controller: codeCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Semester Code (e.g. FALL-2026)'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty ||
                  codeCtrl.text.trim().isEmpty) {
                return;
              }
              final nav = Navigator.of(ctx);
              try {
                final newSem = Semester(
                  id: '',
                  subjectId: selectedSubject.id,
                  name: nameCtrl.text.trim(),
                  code: codeCtrl.text.trim(),
                  orderNumber: _semesters.length + 1,
                  startDate: DateTime.now(),
                  endDate: DateTime.now().add(const Duration(days: 120)),
                  status: 'active',
                );

                await _semesterRepo.createSemester(newSem);
                nav.pop();
                _loadCurriculum();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${context.tr('Failed to create semester')}: $e',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(context.tr('Create')),
          ),
        ],
      ),
    );
  }

  void _showCreateUnitDialog(Semester semester) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${context.tr('Create Unit in')} ${semester.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Unit Name (e.g. Unit 1: Algorithms)'),
              ),
            ),
            TextField(
              controller: codeCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Unit Code (e.g. U1-ALG)'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty ||
                  codeCtrl.text.trim().isEmpty) {
                return;
              }
              final nav = Navigator.of(ctx);
              try {
                final newUnit = Unit(
                  id: '',
                  semesterId: semester.id,
                  name: nameCtrl.text.trim(),
                  code: codeCtrl.text.trim(),
                  orderNumber: semester.units.length + 1,
                  status: 'active',
                );

                await _unitRepo.createUnit(newUnit);
                nav.pop();
                _loadCurriculum();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${context.tr('Failed to create unit')}: $e',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(context.tr('Create Unit')),
          ),
        ],
      ),
    );
  }

  void _showCreateLessonDialog(Unit unit) {
    final titleCtrl = TextEditingController();
    String lessonTypeStr = 'video';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('${context.tr('Create Lesson in')} ${unit.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Lesson Title'),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: lessonTypeStr,
                  decoration: InputDecoration(
                    labelText: context.tr('Lesson Type'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'video',
                      child: Text(context.tr('Video')),
                    ),
                    DropdownMenuItem(
                      value: 'pdf',
                      child: Text(context.tr('PDF / Document')),
                    ),
                    DropdownMenuItem(
                      value: 'quiz',
                      child: Text(context.tr('Interactive Quiz')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setStateDialog(() => lessonTypeStr = v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('Cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  final nav = Navigator.of(ctx);
                  try {
                    final newLesson = Lesson(
                      id: '',
                      unitId: unit.id,
                      title: titleCtrl.text.trim(),
                      lessonType: LessonType.fromString(lessonTypeStr),
                      orderNumber: unit.lessons.length + 1,
                      status: LessonStatus.draft,
                    );

                    await _lessonRepo.createLesson(newLesson);
                    nav.pop();
                    _loadCurriculum();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${context.tr('Failed to create lesson')}: $e',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Text(context.tr('Create Lesson')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUploadResourceDialog(Lesson lesson) {
    final titleCtrl = TextEditingController(
      text: '${lesson.title} Resource PDF',
    );
    final objectPathCtrl = TextEditingController(text: 'lessons/${lesson.id}/');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${context.tr('Attach PDF Resource')} (${lesson.title})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Resource Title'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: objectPathCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Storage object path'),
                hintText: 'lessons/<lesson-id>/lecture.pdf',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: Text(context.tr('Attach Resource')),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty ||
                  objectPathCtrl.text.trim().isEmpty) {
                return;
              }

              final nav = Navigator.of(ctx);
              try {
                final objectPath = objectPathCtrl.text.trim();

                final res = LessonResource(
                  id: '',
                  lessonId: lesson.id,
                  title: titleCtrl.text.trim(),
                  resourceType: 'pdf',
                  bucket: 'curriculum_assets',
                  objectPath: objectPath,
                  orderNumber: lesson.resources.length + 1,
                );

                await _resourceRepo.createResource(res);
                nav.pop();
                _loadCurriculum();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr('PDF resource attached!')),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${context.tr('Upload failed')}: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'Curriculum Editor',
      subtitle: 'Build semesters, units, lessons, and protected resources.',
      icon: Icons.auto_stories,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'Refresh',
          onPressed: _loadCurriculum,
        ),
        if (_selectedSubject != null)
          PortalAction(
            icon: Icons.add,
            label: 'Add Semester',
            onPressed: _showCreateSemesterDialog,
            primary: true,
          ),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: false,
        emptyTitle: 'No curriculum data',
        emptySubtitle: 'Create an active subject first.',
        emptyIcon: Icons.auto_stories,
        onRetry: _loadCurriculum,
        child: Column(
          children: [
            if (_subjects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<SubjectEntity>(
                  initialValue: _selectedSubject,
                  decoration: InputDecoration(labelText: context.tr('Subject')),
                  items: _subjects
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text('${s.name} (${s.code})'),
                        ),
                      )
                      .toList(),
                  onChanged: (subject) {
                    if (subject == null) return;
                    setState(() => _selectedSubject = subject);
                    _loadCurriculum();
                  },
                ),
              ),
            Expanded(
              child: _selectedSubject == null
                  ? Center(child: Text(context.tr('No active subjects found.')))
                  : _semesters.isEmpty
                  ? Center(
                      child: Text(
                        context.tr(
                          'No semesters found. Add a semester to start.',
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _semesters.length,
                      itemBuilder: (ctx, semIdx) {
                        final sem = _semesters[semIdx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            leading: const Icon(
                              Icons.school,
                              color: Colors.blue,
                            ),
                            title: Text(
                              sem.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              '${context.tr('Code')}: ${sem.code} | ${context.tr('Units')}: ${sem.units.length}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                                  onPressed: () => _showCreateUnitDialog(sem),
                                  tooltip: context.tr('Add Unit'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Semester'),
                                        content: const Text('Are you sure?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _semesterRepo.deleteSemester(sem.id);
                                      _loadCurriculum();
                                    }
                                  },
                                  tooltip: context.tr('Delete Semester'),
                                ),
                              ],
                            ),
                            children: sem.units.map((unit) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: ExpansionTile(
                                  leading: const Icon(
                                    Icons.folder,
                                    color: Colors.orange,
                                  ),
                                  title: Text(
                                    unit.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${context.tr('Lessons')}: ${unit.lessons.length}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: Colors.orange),
                                        onPressed: () => _showCreateLessonDialog(unit),
                                        tooltip: context.tr('Add Lesson'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Delete Unit'),
                                              content: const Text('Are you sure?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await _unitRepo.deleteUnit(unit.id);
                                            _loadCurriculum();
                                          }
                                        },
                                        tooltip: context.tr('Delete Unit'),
                                      ),
                                    ],
                                  ),
                                  children: unit.lessons.map((lesson) {
                                    final isPublished =
                                        lesson.status == LessonStatus.published;

                                    return ExpansionTile(
                                      leading: const Icon(
                                        Icons.play_circle_outline,
                                        color: Colors.green,
                                      ),
                                      title: Text(lesson.title),
                                      subtitle: Text(
                                        '${context.tr('Type')}: ${context.tr(lesson.lessonType.name)} | ${context.tr('Status')}: ${context.tr(lesson.status.name)} | ${context.tr('Attachments')}: ${lesson.resources.length}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.attach_file,
                                              color: Colors.purple,
                                            ),
                                            onPressed: () =>
                                                _showUploadResourceDialog(
                                                  lesson,
                                                ),
                                            tooltip: context.tr(
                                              'Upload Private PDF Resource',
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              isPublished
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                              color: isPublished
                                                  ? Colors.green
                                                  : Colors.grey,
                                            ),
                                            onPressed: () async {
                                              await _lessonRepo.publishLesson(
                                                lesson.id,
                                                publish: !isPublished,
                                              );
                                              _loadCurriculum();
                                            },
                                            tooltip: context.tr(
                                              'Toggle Publish',
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Delete Lesson'),
                                                  content: const Text('Are you sure?'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await _lessonRepo.deleteLesson(lesson.id);
                                                _loadCurriculum();
                                              }
                                            },
                                            tooltip: context.tr('Delete Lesson'),
                                          ),
                                        ],
                                      ),
                                      children: lesson.resources.map((res) {
                                        return ListTile(
                                          leading: const Icon(
                                            Icons.picture_as_pdf,
                                            color: Colors.red,
                                          ),
                                          title: Text(res.title),
                                          subtitle: Text(
                                            '${context.tr('Path')}: ${res.bucket}/${res.objectPath}',
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  }).toList(),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
