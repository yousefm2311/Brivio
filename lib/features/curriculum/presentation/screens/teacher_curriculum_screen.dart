import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
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
                      child: Text(context.tr('PDF')),
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
      text: '${lesson.title} PDF Resource',
    );
    XFile? selectedFile;
    bool isUploading = false;
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${context.tr('Upload PDF')} (${lesson.title})'),
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
                label: Text(context.tr('Choose PDF')),
              ),
              const SizedBox(height: 8),
              Text(
                selectedFile == null
                    ? context.tr('No PDF selected.')
                    : '${context.tr('Selected')}: ${selectedFile!.name}',
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
              child: Text(context.tr('Cancel')),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: Text(context.tr('Upload & Attach')),
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
                            SnackBar(
                              content: Text(
                                context.tr('PDF uploaded and attached.'),
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isUploading = false);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '${context.tr('Upload failed')}: $e',
                              ),
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

  void _showCodeChallengesDialog(Lesson lesson) {
    showDialog(
      context: context,
      builder: (_) => _LessonCodeChallengeDialog(lesson: lesson),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Academic Curriculum Hierarchy')),
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
                    '${context.tr('Error')}: $_errorMessage',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadCurriculum,
                    child: Text(context.tr('Retry')),
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
                Expanded(
                  child: Center(
                    child: Text(
                      context.tr(
                        'No semesters found for your taught subjects.',
                      ),
                    ),
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
                            '${context.tr('Code')}: ${sem.code} | ${context.tr('Units')}: ${sem.units.length}',
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
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.orange,
                                  ),
                                  onPressed: () =>
                                      _showCreateLessonDialog(unit),
                                  tooltip: context.tr('Add Lesson'),
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
                                      '${context.tr('Type')}: ${context.tr(lesson.lessonType.name)} | ${context.tr('Status')}: ${context.tr(lesson.status.name)}',
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
                                          tooltip: context.tr(
                                            'Upload Resource',
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.code,
                                            color: Colors.indigo,
                                          ),
                                          onPressed: () =>
                                              _showCodeChallengesDialog(lesson),
                                          tooltip: context.tr(
                                            'Code Challenges',
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
                                            );
                                            _loadCurriculum();
                                          },
                                          tooltip: context.tr('Toggle Publish'),
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
    );
  }
}

class _LessonCodeChallengeDialog extends StatefulWidget {
  final Lesson lesson;

  const _LessonCodeChallengeDialog({required this.lesson});

  @override
  State<_LessonCodeChallengeDialog> createState() =>
      _LessonCodeChallengeDialogState();
}

class _LessonCodeChallengeDialogState
    extends State<_LessonCodeChallengeDialog> {
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _xpCtrl = TextEditingController(text: '50');
  final List<_ChallengeCaseDraft> _caseDrafts = [_ChallengeCaseDraft()];

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String _difficulty = 'medium';
  String _status = 'published';
  List<_TeacherCodeChallenge> _challenges = [];

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _xpCtrl.dispose();
    for (final draft in _caseDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _loadChallenges() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rows = await Supabase.instance.client.rpc(
        'get_teacher_lesson_code_challenges',
        params: {'p_lesson_id': widget.lesson.id},
      );
      if (!mounted) return;
      setState(() {
        _challenges = (rows as List)
            .whereType<Map>()
            .map(_TeacherCodeChallenge.fromJson)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createChallenge() async {
    final title = _titleCtrl.text.trim();
    final validCases = _caseDrafts
        .where((draft) => draft.expectedCtrl.text.trim().isNotEmpty)
        .toList();
    if (title.isEmpty || validCases.isEmpty) {
      setState(() {
        _errorMessage =
            'Challenge title and at least one expected output are required.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.rpc(
        'create_code_challenge_with_cases',
        params: {
          'p_lesson_id': widget.lesson.id,
          'p_title': title,
          'p_description': _descriptionCtrl.text.trim(),
          'p_difficulty': _difficulty,
          'p_xp_reward': int.tryParse(_xpCtrl.text.trim()) ?? 50,
          'p_status': _status,
          'p_test_cases': validCases
              .asMap()
              .entries
              .map(
                (entry) => {
                  'name': entry.value.nameCtrl.text.trim().isEmpty
                      ? 'Case ${entry.key + 1}'
                      : entry.value.nameCtrl.text.trim(),
                  'stdin': entry.value.stdinCtrl.text,
                  'expected_stdout': entry.value.expectedCtrl.text,
                  'is_hidden': entry.value.isHidden,
                },
              )
              .toList(),
        },
      );

      _titleCtrl.clear();
      _descriptionCtrl.clear();
      _xpCtrl.text = '50';
      for (final draft in _caseDrafts) {
        draft.dispose();
      }
      _caseDrafts
        ..clear()
        ..add(_ChallengeCaseDraft());
      _difficulty = 'medium';
      _status = 'published';
      await _loadChallenges();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changeStatus(
    _TeacherCodeChallenge challenge,
    String status,
  ) async {
    try {
      await Supabase.instance.client.rpc(
        'update_code_challenge_status',
        params: {'p_challenge_id': challenge.id, 'p_status': status},
      );
      await _loadChallenges();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${context.tr('Code Challenges')} - ${widget.lesson.title}'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr(
                        'Published challenges appear in the student code workspace.',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Refresh'),
                    onPressed: _isLoading ? null : _loadChallenges,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const LinearProgressIndicator()
              else if (_challenges.isEmpty)
                Text(context.tr('No challenges created for this lesson yet.'))
              else
                ..._challenges.map(
                  (challenge) => Card(
                    child: ListTile(
                      leading: Icon(
                        challenge.status == 'published'
                            ? Icons.verified
                            : Icons.pending_outlined,
                        color: challenge.status == 'published'
                            ? Colors.green
                            : Colors.grey,
                      ),
                      title: Text(challenge.title),
                      subtitle: Text(
                        '${challenge.difficulty} | ${challenge.xpReward} XP | '
                        '${challenge.testCaseCount} cases | '
                        '${challenge.passedCount}/${challenge.attemptsCount} passed',
                      ),
                      trailing: DropdownButton<String>(
                        value: challenge.status,
                        items: [
                          DropdownMenuItem(
                            value: 'draft',
                            child: Text(context.tr('draft')),
                          ),
                          DropdownMenuItem(
                            value: 'published',
                            child: Text(context.tr('published')),
                          ),
                          DropdownMenuItem(
                            value: 'archived',
                            child: Text(context.tr('archived')),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null || value == challenge.status) {
                            return;
                          }
                          _changeStatus(challenge, value);
                        },
                      ),
                    ),
                  ),
                ),
              const Divider(height: 28),
              Text(
                context.tr('Create Challenge'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(labelText: context.tr('Title')),
              ),
              TextField(
                controller: _descriptionCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Description'),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _difficulty,
                      decoration: InputDecoration(
                        labelText: context.tr('Difficulty'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'easy',
                          child: Text(context.tr('easy')),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text(context.tr('medium')),
                        ),
                        DropdownMenuItem(
                          value: 'hard',
                          child: Text(context.tr('hard')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _difficulty = value);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _xpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: context.tr('XP')),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: InputDecoration(
                        labelText: context.tr('Status'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'draft',
                          child: Text(context.tr('draft')),
                        ),
                        DropdownMenuItem(
                          value: 'published',
                          child: Text(context.tr('published')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _status = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _caseDrafts.length; i++)
                _ChallengeCaseEditor(
                  index: i,
                  draft: _caseDrafts[i],
                  canRemove: _caseDrafts.length > 1,
                  onChanged: () => setState(() {}),
                  onRemove: () {
                    setState(() {
                      final removed = _caseDrafts.removeAt(i);
                      removed.dispose();
                    });
                  },
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _caseDrafts.add(_ChallengeCaseDraft())),
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('Add Test Case')),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(context.tr('Close')),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _createChallenge,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(context.tr('Create Challenge')),
        ),
      ],
    );
  }
}

class _ChallengeCaseEditor extends StatelessWidget {
  final int index;
  final _ChallengeCaseDraft draft;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _ChallengeCaseEditor({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${context.tr('Test Case')} ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Checkbox(
                  value: draft.isHidden,
                  onChanged: (value) {
                    draft.isHidden = value ?? false;
                    onChanged();
                  },
                ),
                Text(context.tr('Hidden')),
                IconButton(
                  onPressed: canRemove ? onRemove : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextField(
              controller: draft.nameCtrl,
              decoration: InputDecoration(labelText: context.tr('Case Name')),
            ),
            TextField(
              controller: draft.stdinCtrl,
              decoration: InputDecoration(labelText: context.tr('Input stdin')),
              minLines: 1,
              maxLines: 4,
            ),
            TextField(
              controller: draft.expectedCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Expected stdout'),
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeCaseDraft {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController stdinCtrl = TextEditingController();
  final TextEditingController expectedCtrl = TextEditingController();
  bool isHidden = false;

  void dispose() {
    nameCtrl.dispose();
    stdinCtrl.dispose();
    expectedCtrl.dispose();
  }
}

class _TeacherCodeChallenge {
  final String id;
  final String title;
  final String difficulty;
  final int xpReward;
  final String status;
  final int testCaseCount;
  final int attemptsCount;
  final int passedCount;

  const _TeacherCodeChallenge({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.xpReward,
    required this.status,
    required this.testCaseCount,
    required this.attemptsCount,
    required this.passedCount,
  });

  factory _TeacherCodeChallenge.fromJson(Map<dynamic, dynamic> json) {
    final testCases = json['test_cases'];
    return _TeacherCodeChallenge(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Challenge',
      difficulty: json['difficulty']?.toString() ?? 'medium',
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'draft',
      testCaseCount: testCases is List ? testCases.length : 0,
      attemptsCount: (json['attempts_count'] as num?)?.toInt() ?? 0,
      passedCount: (json['passed_count'] as num?)?.toInt() ?? 0,
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
        decoration: InputDecoration(
          labelText: context.tr('Assigned group'),
          border: const OutlineInputBorder(),
        ),
        items: groups
            .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
            .toList(),
        onChanged: groups.isEmpty ? null : onChanged,
      ),
    );
  }
}
