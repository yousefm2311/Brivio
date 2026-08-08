import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
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
    _loadCurriculum();
  }

  Future<void> _loadCurriculum() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sList = await _semesterRepo.fetchSemestersForSubject(
        '30000000-0000-0000-0000-000000000001',
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
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Semester'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Semester Name (e.g. Fall 2026)',
              ),
            ),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Semester Code (e.g. FALL-2026)',
              ),
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
              if (nameCtrl.text.trim().isEmpty ||
                  codeCtrl.text.trim().isEmpty) {
                return;
              }
              final nav = Navigator.of(ctx);
              try {
                final newSem = Semester(
                  id: '',
                  subjectId: '30000000-0000-0000-0000-000000000001',
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
                      content: Text('Failed to create semester: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
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
        title: Text('Create Unit in ${semester.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Unit Name (e.g. Unit 1: Algorithms)',
              ),
            ),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Unit Code (e.g. U1-ALG)',
              ),
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
                      content: Text('Failed to create unit: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create Unit'),
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
                    DropdownMenuItem(
                      value: 'document',
                      child: Text('PDF / Document'),
                    ),
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
      text: '${lesson.title} Resource PDF',
    );
    final filenameCtrl = TextEditingController(text: 'sample_lecture.pdf');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Upload PDF Resource to Private Bucket (${lesson.title})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Resource Title'),
            ),
            TextField(
              controller: filenameCtrl,
              decoration: const InputDecoration(
                labelText: 'Target File Name in curriculum_assets',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Uploads binary PDF stream directly to private Supabase Storage bucket: curriculum_assets',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Upload & Attach'),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty ||
                  filenameCtrl.text.trim().isEmpty)
                return;

              final nav = Navigator.of(ctx);
              try {
                // Generate canonical PDF bytes for test upload
                final samplePdfContent =
                    '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj 3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R>>endobj\nxref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000052 00000 n\n0000000102 00000 n\ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n178\n%%EOF';
                final bytes = Uint8List.fromList(samplePdfContent.codeUnits);
                final objectPath =
                    'lessons/${lesson.id}/${filenameCtrl.text.trim()}';

                // Upload to private bucket curriculum_assets
                await Supabase.instance.client.storage
                    .from('curriculum_assets')
                    .uploadBinary(
                      objectPath,
                      bytes,
                      fileOptions: const FileOptions(upsert: true),
                    );

                // Create LessonResource DB record
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
                    const SnackBar(
                      content: Text(
                        'PDF uploaded to private storage & attached!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Curriculum Hierarchy Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCurriculum,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSemesterDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Semester'),
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
          ? const Center(
              child: Text('No semesters found. Add a semester to start!'),
            )
          : ListView.builder(
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
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                      onPressed: () => _showCreateUnitDialog(sem),
                      tooltip: 'Add Unit',
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
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('Lessons: ${unit.lessons.length}'),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.orange,
                            ),
                            onPressed: () => _showCreateLessonDialog(unit),
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
                                'Type: ${lesson.lessonType.name.toUpperCase()} | Status: ${lesson.status.name.toUpperCase()} | Attachments: ${lesson.resources.length}',
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
                                    tooltip: 'Upload Private PDF Resource',
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
    );
  }
}
