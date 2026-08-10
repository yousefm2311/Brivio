import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../widgets/account_login_qr_dialog.dart';

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
      if (mounted) {
        setState(() {
          _parents = res.data;
          _students = sRes.data;
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

  void _showProvisionParentDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Provision New Parent Account')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: context.tr('Full Name')),
              ),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Email Address'),
                ),
                keyboardType: TextInputType.emailAddress,
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

              final nav = Navigator.of(ctx);
              try {
                final response = await Supabase.instance.client.functions
                    .invoke(
                      'provision-user',
                      body: {
                        'email': emailCtrl.text.trim(),
                        'fullName': nameCtrl.text.trim(),
                        'role': 'parent',
                      },
                    );

                if (response.status != 200) {
                  final err = response.data is Map
                      ? response.data['error']
                      : 'Provisioning failed';
                  throw Exception(err ?? 'Status ${response.status}');
                }

                nav.pop();
                _loadParents();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Parent account provisioned successfully!'),
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
                  return PortalListCard(
                    icon: Icons.family_restroom,
                    accentColor: AppColors.parentRole,
                    title: p.fullName,
                    subtitle: '${context.tr('Email')}: ${p.email}',
                    trailing: [
                      IconButton(
                        tooltip: context.tr('Login QR'),
                        onPressed: () => _showLoginQr(p),
                        icon: const Icon(Icons.qr_code_2),
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
