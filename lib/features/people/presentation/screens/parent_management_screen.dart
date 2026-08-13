import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../widgets/account_login_qr_dialog.dart';
import '../widgets/account_password_dialog.dart';

class ParentManagementScreen extends StatefulWidget {
  const ParentManagementScreen({super.key});

  @override
  State<ParentManagementScreen> createState() => _ParentManagementScreenState();
}

class _ParentManagementScreenState extends State<ParentManagementScreen> {
  late final SupabaseParentRepository _parentRepo;
  late final SupabaseStudentRepository _studentRepo;

  List<Parent> _parents = [];
  List<Student> _students = [];
  Map<String, List<Student>> _linkedStudents = {};
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _parentRepo = SupabaseParentRepository(wrapper);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _loadParents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _parentRepo.fetchParents();
      final sRes = await _studentRepo.fetchStudents();

      final Map<String, List<Student>> linked = {};
      final futures = res.data.map((p) async {
        try {
          linked[p.id] = await _parentRepo.fetchLinkedStudents(p.id);
        } catch (_) {
          linked[p.id] = [];
        }
      });
      await Future.wait(futures);

      if (mounted) {
        setState(() {
          _parents = res.data;
          _students = sRes.data;
          _linkedStudents = linked;
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

  void _showEditParentDialog(Parent parent) {
    final nameCtrl = TextEditingController(text: parent.fullName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Edit Parent')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: context.tr('Full Name')),
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
              if (nameCtrl.text.trim().isEmpty) return;

              final nav = Navigator.of(ctx);
              try {
                await Supabase.instance.client
                    .from('profiles')
                    .update({'full_name': nameCtrl.text.trim()})
                    .eq('id', parent.profileId);

                nav.pop();
                _loadParents();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Parent updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Update error: $e'),
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
    );
  }

  void _showProvisionParentDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(context.tr('Provision New Parent Account')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Full Name'),
                  ),
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Email Address'),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: context.tr('Password (optional)'),
                    helperText: context.tr(
                      'Leave empty if the parent will set it after QR login.',
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setStateDialog(
                        () => obscurePassword = !obscurePassword,
                      ),
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                  ),
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
                    emailCtrl.text.trim().isEmpty) {
                  return;
                }
                if (passwordCtrl.text.isNotEmpty &&
                    passwordCtrl.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final nav = Navigator.of(ctx);
                try {
                  final response = await Supabase.instance.client.functions
                      .invoke(
                        'provision-user',
                        body: {
                          'email': emailCtrl.text.trim(),
                          'fullName': nameCtrl.text.trim(),
                          'role': 'parent',
                          if (passwordCtrl.text.isNotEmpty)
                            'password': passwordCtrl.text,
                        },
                      );

                  if (response.status < 200 || response.status >= 300) {
                    final data = response.data;
                    final message = data is Map
                        ? data['error']?.toString()
                        : null;
                    throw Exception(message ?? 'Provisioning failed.');
                  }
                  final data = Map<String, dynamic>.from(response.data as Map);
                  if (data['success'] != true) {
                    throw Exception('Provisioning failed.');
                  }

                  nav.pop();
                  _loadParents();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Parent account provisioned successfully!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Provisioning error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(context.tr('Provision Parent')),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkStudentDialog(Parent parent) {
    String? selectedStudentId = _students.isNotEmpty
        ? _students.first.id
        : null;
    String relationshipType = 'guardian';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Link Child to ${parent.fullName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_students.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedStudentId,
                  decoration: InputDecoration(
                    labelText: context.tr('Select Child / Student'),
                  ),
                  items: _students
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.fullName} (${s.studentCode})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setStateDialog(() => selectedStudentId = v),
                ),
              DropdownButtonFormField<String>(
                initialValue: relationshipType,
                decoration: InputDecoration(
                  labelText: context.tr('Relationship Type'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'father',
                    child: Text(context.tr('Father')),
                  ),
                  DropdownMenuItem(
                    value: 'mother',
                    child: Text(context.tr('Mother')),
                  ),
                  DropdownMenuItem(
                    value: 'guardian',
                    child: Text(context.tr('Guardian')),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setStateDialog(() => relationshipType = v);
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
                if (selectedStudentId == null) return;
                final nav = Navigator.of(ctx);
                try {
                  await _parentRepo.linkParentToStudent(
                    parentId: parent.id,
                    studentId: selectedStudentId!,
                    relationshipType: relationshipType,
                  );
                  nav.pop();
                  _loadParents();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Child linked successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Linking failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(context.tr('Link Child')),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginQr(Parent parent) {
    showDialog(
      context: context,
      builder: (_) => AccountLoginQrDialog(
        profileId: parent.profileId,
        displayName: parent.fullName,
        email: parent.email,
      ),
    );
  }

  void _showPasswordDialog(Parent parent) {
    showDialog(
      context: context,
      builder: (_) => AccountPasswordDialog(
        profileId: parent.profileId,
        displayName: parent.fullName,
        email: parent.email,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _parents.where((p) {
      final q = _searchController.text.toLowerCase();
      return p.fullName.toLowerCase().contains(q) ||
          p.email.toLowerCase().contains(q);
    }).toList();

    return PortalPageShell(
      title: 'Parent Management',
      subtitle: 'Provision guardian accounts and link them to students.',
      icon: Icons.family_restroom,
      accentColor: AppColors.parentRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'Refresh',
          onPressed: _loadParents,
        ),
        PortalAction(
          icon: Icons.person_add,
          label: 'Provision Parent',
          onPressed: _showProvisionParentDialog,
          primary: true,
        ),
      ],
      child: Column(
        children: [
          PortalSearchField(
            controller: _searchController,
            label: 'Search parents',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: 'No parents found',
              emptySubtitle: 'Provision guardian accounts, then link children.',
              emptyIcon: Icons.family_restroom,
              onRetry: _loadParents,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final p = filtered[i];
                  final linked = _linkedStudents[p.id] ?? [];
                  final childrenNames = linked
                      .map((s) => s.fullName)
                      .join(', ');

                  return PortalListCard(
                    icon: Icons.family_restroom,
                    accentColor: AppColors.parentRole,
                    title: p.fullName,
                    subtitle:
                        '${context.tr('Email')}: ${p.email}'
                        '${childrenNames.isNotEmpty ? '\n${context.tr('Children')}: $childrenNames' : ''}',
                    trailing: [
                      IconButton(
                        tooltip: context.tr('Login QR'),
                        onPressed: () => _showLoginQr(p),
                        icon: const Icon(Icons.qr_code_2),
                      ),
                      IconButton(
                        tooltip: context.tr('Set Password'),
                        onPressed: () => _showPasswordDialog(p),
                        icon: const Icon(Icons.password),
                      ),
                      if (p.status == 'suspended')
                        IconButton(
                          tooltip: context.tr('Activate Parent'),
                          onPressed: () async {
                            try {
                              await Supabase.instance.client.rpc(
                                'activate_user',
                                params: {'user_uid': p.profileId},
                              );
                              _loadParents();
                            } catch (err) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to activate: $err'),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                        )
                      else
                        IconButton(
                          tooltip: context.tr('Suspend Parent'),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Suspend Parent'),
                                content: const Text(
                                  'Are you sure you want to suspend this parent?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text(
                                      'Suspend',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await Supabase.instance.client.rpc(
                                  'suspend_user',
                                  params: {'user_uid': p.profileId},
                                );
                                _loadParents();
                              } catch (err) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to suspend: $err'),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.block, color: Colors.red),
                        ),
                      IconButton(
                        tooltip: context.tr('Edit Parent'),
                        onPressed: () => _showEditParentDialog(p),
                        icon: const Icon(Icons.edit, color: Colors.blue),
                      ),
                      IconButton(
                        tooltip: context.tr('Delete Parent'),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Parent'),
                              content: const Text(
                                'Are you sure you want to permanently delete this parent?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await Supabase.instance.client.rpc(
                                'hard_delete_user',
                                params: {'target_user_id': p.profileId},
                              );
                              _loadParents();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showLinkStudentDialog(p),
                        icon: const Icon(Icons.link),
                        label: Text(context.tr('Link Child')),
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
