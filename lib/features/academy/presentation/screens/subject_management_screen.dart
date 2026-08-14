import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
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
        title: Text(context.tr('Create New Subject')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: context.tr(
                    'Subject Name (e.g. Programming Fundamentals)',
                  ),
                ),
              ),
              TextField(
                controller: codeCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Subject Code (e.g. CS-101)'),
                ),
              ),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Description'),
                ),
                maxLines: 2,
              ),
            ],
          ),
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
                      content: Text(
                        '${context.tr('Failed to create subject')}: $e',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(context.tr('Create Subject')),
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
          title: Text('${context.tr('Edit Subject')} (${subject.code})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Subject Name'),
                  ),
                ),
                TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Subject Code'),
                  ),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Description'),
                  ),
                  maxLines: 2,
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(labelText: context.tr('Status')),
                  items: [
                    DropdownMenuItem(
                      value: 'active',
                      child: Text(context.tr('active')),
                    ),
                    DropdownMenuItem(
                      value: 'archived',
                      child: Text(context.tr('archived')),
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
                      SnackBar(
                        content: Text(
                          context.tr('Subject updated successfully!'),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${context.tr('Failed to update subject')}: $e',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(context.tr('Save Changes')),
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

    return PortalPageShell(
      title: 'Subject Management',
      subtitle: 'Manage the curriculum subjects used by groups and content.',
      icon: Icons.book,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'Refresh',
          onPressed: _loadSubjects,
        ),
        PortalAction(
          icon: Icons.add,
          label: 'Add Subject',
          onPressed: _showCreateSubjectDialog,
          primary: true,
        ),
      ],
      child: Column(
        children: [
          PortalSearchField(
            controller: _searchController,
            label: 'Search subjects',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: 'No subjects found',
              emptySubtitle: 'Add a subject or change your search.',
              emptyIcon: Icons.book,
              onRetry: _loadSubjects,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final s = filtered[i];
                  return PortalListCard(
                    icon: Icons.book,
                    accentColor: AppColors.adminRole,
                    title: s.name,
                    subtitle:
                        'Code: ${s.code} | Description: ${s.description ?? "N/A"}',
                    trailing: [
                      PortalStatusChip(status: s.status),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditSubjectDialog(s),
                        tooltip: 'Edit Subject',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Subject'),
                              content: const Text(
                                'Are you sure you want to delete this subject?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await _subjectRepo.deleteSubject(s.id);
                              _loadSubjects();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete: $e'),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        tooltip: 'Delete Subject',
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
