import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_curriculum_repositories.dart';
import '../../domain/models/curriculum_models.dart';

class TeacherCurriculumScreen extends StatefulWidget {
  final String teacherId;

  const TeacherCurriculumScreen({super.key, required this.teacherId});

  @override
  State<TeacherCurriculumScreen> createState() =>
      _TeacherCurriculumScreenState();
}

class _TeacherCurriculumScreenState extends State<TeacherCurriculumScreen> {
  late final SupabaseSemesterRepository _semesterRepo;
  late final SupabaseUnitRepository _unitRepo;
  late final SupabaseLessonRepository _lessonRepo;
  late final SupabaseLessonResourceRepository _resourceRepo;
  late final SupabaseTeacherRepository _teacherRepo;

  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
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
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _loadCurriculum();
  }

  Future<void> _loadCurriculum() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      GroupEntity? selected;
      if (_selectedGroup == null) {
        selected = groups.isNotEmpty ? groups.first : null;
      } else {
        for (final group in groups) {
          if (group.id == _selectedGroup!.id) {
            selected = group;
            break;
          }
        }
      }

      if (selected == null) {
        if (!mounted) return;
        setState(() {
          _groups = groups;
          _selectedGroup = null;
          _semesters = [];
          _isLoading = false;
        });
        return;
      }

      final sList = await _semesterRepo.fetchSemestersForSubject(
        selected.subjectId,
      );
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
          _groups = groups;
          _selectedGroup = selected;
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

  Future<void> _selectGroup(GroupEntity? group) async {
    setState(() => _selectedGroup = group);
    await _loadCurriculum();
  }

  void _showCreateLessonDialog(Unit unit) {
    final titleCtrl = TextEditingController();
    String lessonTypeStr = 'video';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Create Lesson in ${unit.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Lesson Title'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: lessonTypeStr,
                  decoration: const InputDecoration(labelText: 'Lesson Type'),
                  items: const [
                    DropdownMenuItem(value: 'video', child: Text('Video')),
                    DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                    DropdownMenuItem(
                      value: 'quiz',
                      child: Text('Interactive Quiz'),
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
                child: const Text('Cancel'),
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
                          content: Text('Failed to create lesson: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Create Lesson'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUploadResourceDialog(Lesson lesson) {
    final titleCtrl = TextEditingController(
      text: '${lesson.title} PDF Resource',
    );
    XFile? selectedFile;
    bool isUploading = false;
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Upload PDF (${lesson.title})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Resource Title'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isUploading
                    ? null
                    : () async {
                        final file = await openFile(
                          acceptedTypeGroups: const [
                            XTypeGroup(
                              label: 'PDF',
                              extensions: ['pdf'],
                              mimeTypes: ['application/pdf'],
                            ),
                          ],
                        );
                        if (file == null) return;
                        setDialogState(() {
                          selectedFile = file;
                          if (titleCtrl.text.trim().isEmpty) {
                            titleCtrl.text = file.name;
                          }
                        });
                      },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Choose PDF'),
              ),
              const SizedBox(height: 8),
              Text(
                selectedFile == null
                    ? 'No PDF selected.'
                    : 'Selected: ${selectedFile!.name}',
                textAlign: TextAlign.center,
              ),
              if (isUploading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload & Attach'),
              onPressed: isUploading
                  ? null
                  : () async {
                      final file = selectedFile;
                      final bytes = file == null
                          ? null
                          : await file.readAsBytes();
                      if (titleCtrl.text.trim().isEmpty ||
                          file == null ||
                          bytes == null) {
                        return;
                      }

                      final nav = Navigator.of(ctx);
                      setDialogState(() => isUploading = true);
                      try {
                        final objectPath = _buildLessonResourcePath(
                          lesson.id,
                          file.name,
                        );
                        await Supabase.instance.client.storage
                            .from('curriculum_assets')
                            .uploadBinary(
                              objectPath,
                              Uint8List.fromList(bytes),
                              fileOptions: const FileOptions(
                                contentType: 'application/pdf',
                                upsert: true,
                              ),
                            );

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
                        await _loadCurriculum();
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('PDF uploaded and attached.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isUploading = false);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Upload failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  String _buildLessonResourcePath(String lessonId, String fileName) {
    final safeName = fileName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return 'lessons/$lessonId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Curriculum Hierarchy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCurriculum,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: $_errorMessage',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadCurriculum,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _semesters.isEmpty
          ? Column(
              children: [
                _GroupPicker(
                  groups: _groups,
                  selectedGroup: _selectedGroup,
                  onChanged: _selectGroup,
                ),
                const Expanded(
                  child: Center(
                    child: Text('No semesters found for your taught subjects.'),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _GroupPicker(
                  groups: _groups,
                  selectedGroup: _selectedGroup,
                  onChanged: _selectGroup,
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _semesters.length,
                    itemBuilder: (ctx, semIdx) {
                      final sem = _semesters[semIdx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                          leading: const Icon(Icons.school, color: Colors.blue),
                          title: Text(
                            sem.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            'Code: ${sem.code} | Units: ${sem.units.length}',
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
                                  'Lessons: ${unit.lessons.length}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.orange,
                                  ),
                                  onPressed: () =>
                                      _showCreateLessonDialog(unit),
                                  tooltip: 'Add Lesson',
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
                                      'Type: ${lesson.lessonType.name.toUpperCase()} | Status: ${lesson.status.name.toUpperCase()}',
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
                                              _showUploadResourceDialog(lesson),
                                          tooltip: 'Upload Resource',
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
                                            );
                                            _loadCurriculum();
                                          },
                                          tooltip: 'Toggle Publish',
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
                                          'Path: ${res.bucket}/${res.objectPath}',
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
    );
  }
}

class _GroupPicker extends StatelessWidget {
  final List<GroupEntity> groups;
  final GroupEntity? selectedGroup;
  final ValueChanged<GroupEntity?> onChanged;

  const _GroupPicker({
    required this.groups,
    required this.selectedGroup,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<GroupEntity>(
        initialValue: selectedGroup,
        decoration: const InputDecoration(
          labelText: 'Assigned group',
          border: OutlineInputBorder(),
        ),
        items: groups
            .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
            .toList(),
        onChanged: groups.isEmpty ? null : onChanged,
      ),
    );
  }
}
