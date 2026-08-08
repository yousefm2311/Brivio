import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';

class SubjectManagementScreen extends StatefulWidget {
  const SubjectManagementScreen({super.key});

  @override
  State<SubjectManagementScreen> createState() =>
      _SubjectManagementScreenState();
}

class _SubjectManagementScreenState extends State<SubjectManagementScreen> {
  late final SupabaseSubjectRepository _subjectRepo;
  List<SubjectEntity> _subjects = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _subjectRepo = SupabaseSubjectRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _loadSubjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _subjectRepo.fetchSubjects();
      if (mounted) {
        setState(() {
          _subjects = res;
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

  void _showCreateSubjectDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Subject'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject Name (e.g. Programming Fundamentals)',
                ),
              ),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject Code (e.g. CS-101)',
                ),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
            ],
          ),
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
                final s = SubjectEntity(
                  id: '',
                  code: codeCtrl.text.trim(),
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  status: 'active',
                );

                await _subjectRepo.createSubject(s);
                nav.pop();
                _loadSubjects();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to create subject: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create Subject'),
          ),
        ],
      ),
    );
  }

  void _showEditSubjectDialog(SubjectEntity subject) {
    final nameCtrl = TextEditingController(text: subject.name);
    final codeCtrl = TextEditingController(text: subject.code);
    final descCtrl = TextEditingController(text: subject.description ?? '');
    String status = subject.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Edit Subject (${subject.code})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Subject Name'),
                ),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Subject Code'),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'archived',
                      child: Text('Archived'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setStateDialog(() => status = v);
                  },
                ),
              ],
            ),
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
                  final updated = SubjectEntity(
                    id: subject.id,
                    code: codeCtrl.text.trim(),
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                    status: status,
                  );

                  await _subjectRepo.updateSubject(updated);
                  nav.pop();
                  _loadSubjects();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Subject updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update subject: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _subjects.where((s) {
      final q = _searchController.text.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.code.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subject Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSubjects),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSubjectDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Subject'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Subjects',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _isLoading
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
                          onPressed: _loadSubjects,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : filtered.isEmpty
                ? const Center(child: Text('No subjects found.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final s = filtered[i];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.book)),
                        title: Text(
                          s.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Code: ${s.code} | Description: ${s.description ?? "N/A"}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(s.status.toUpperCase()),
                              backgroundColor: s.status == 'active'
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditSubjectDialog(s),
                              tooltip: 'Edit Subject',
                            ),
                          ],
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
