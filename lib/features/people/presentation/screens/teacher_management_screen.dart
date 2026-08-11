import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../widgets/account_login_qr_dialog.dart';
import '../../../../core/services/report_generator_service.dart';

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  State<TeacherManagementScreen> createState() =>
      _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseBranchRepository _branchRepo;

  List<Teacher> _teachers = [];
  List<Branch> _branches = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _branchRepo = SupabaseBranchRepository(wrapper);
    _loadTeachers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _teacherRepo.fetchTeachers();
      final bRes = await _branchRepo.fetchBranches();
      if (mounted) {
        setState(() {
          _teachers = res.data;
          _branches = bRes;
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

  void _showEditTeacherDialog(Teacher teacher) {
    final nameCtrl = TextEditingController(text: teacher.fullName);
    final specCtrl = TextEditingController(text: teacher.specialization ?? '');
    String? selectedBranchId = teacher.primaryBranchId?.isEmpty == true ? null : teacher.primaryBranchId;
    if (selectedBranchId != null && !_branches.any((b) => b.id == selectedBranchId)) {
      selectedBranchId = null;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(context.tr('Edit Teacher')),
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
                  controller: specCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Specialization'),
                  ),
                ),
                if (_branches.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedBranchId,
                    decoration: InputDecoration(
                      labelText: context.tr('Branch Assignment'),
                    ),
                    items: _branches
                        .map(
                          (b) => DropdownMenuItem<String>(
                            value: b.id,
                            child: Text(b.name),
                          ),
                        )
                        .toList()..insert(0, const DropdownMenuItem(value: null, child: Text('No Branch Assigned'))),
                    onChanged: (v) =>
                        setStateDialog(() => selectedBranchId = v),
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
                      .eq('id', teacher.profileId);
                  
                  await Supabase.instance.client
                      .from('teachers')
                      .update({
                        'specialization': specCtrl.text.trim(),
                        if (selectedBranchId != null) 'primary_branch_id': selectedBranchId,
                      })
                      .eq('id', teacher.id);

                  nav.pop();
                  _loadTeachers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Teacher updated successfully!'),
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
      ),
    );
  }

  void _showProvisionTeacherDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String? selectedBranchId = _branches.isNotEmpty ? _branches.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(context.tr('Provision New Teacher Account')),
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
                if (_branches.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedBranchId,
                    decoration: InputDecoration(
                      labelText: context.tr('Branch Assignment'),
                    ),
                    items: _branches
                        .map(
                          (b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setStateDialog(() => selectedBranchId = v),
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
                  final response = await Supabase.instance.client.rpc(
                    'provision_privileged_user',
                    params: {
                      'p_email': emailCtrl.text.trim(),
                      'p_full_name': nameCtrl.text.trim(),
                      'p_role': 'teacher',
                      if (selectedBranchId != null)
                        'p_branch_id': selectedBranchId,
                    },
                  );

                  if (response == null || (response is Map && response['success'] != true)) {
                    throw Exception('Provisioning failed.');
                  }

                  nav.pop();
                  _loadTeachers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Teacher provisioned with invite email sent!',
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
              child: Text(context.tr('Provision Teacher')),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginQr(Teacher teacher) {
    showDialog(
      context: context,
      builder: (_) => AccountLoginQrDialog(
        profileId: teacher.profileId,
        displayName: teacher.fullName,
        email: teacher.email,
      ),
    );
  }

  Future<void> _exportTeacherData() async {
    try {
      final service = ReportGeneratorService();
      final rosterData = _teachers.map((t) => {
        'name': t.fullName,
        'email': t.email,
        'specialization': t.specialization ?? 'N/A',
        'status': t.status,
      }).toList();
      
      await service.generateTeacherRosterReport(teachersData: rosterData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teacher report generated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate report: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _teachers.where((t) {
      final q = _searchController.text.toLowerCase();
      return t.fullName.toLowerCase().contains(q) ||
          t.email.toLowerCase().contains(q);
    }).toList();

    return PortalPageShell(
      title: 'Teacher Management',
      subtitle: 'Provision teachers and monitor their subject assignments.',
      icon: Icons.person,
      accentColor: AppColors.teacherRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'Refresh',
          onPressed: _loadTeachers,
        ),
        PortalAction(
          icon: Icons.person_add,
          label: 'Provision Teacher',
          onPressed: _showProvisionTeacherDialog,
          primary: true,
        ),
        PortalAction(
          icon: Icons.picture_as_pdf,
          label: 'Export Report',
          onPressed: _exportTeacherData,
          primary: false,
        ),
      ],
      child: Column(
        children: [
          PortalSearchField(
            controller: _searchController,
            label: 'Search teachers',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: 'No teachers found',
              emptySubtitle: 'Provision teacher accounts after branches exist.',
              emptyIcon: Icons.person,
              onRetry: _loadTeachers,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final t = filtered[i];
                  return PortalListCard(
                    icon: Icons.person,
                    accentColor: AppColors.teacherRole,
                    title: t.fullName,
                    subtitle:
                        '${context.tr('Email')}: ${t.email} | ${context.tr('Specialization')}: ${t.specialization ?? context.tr("N/A")}',
                    trailing: [
                      IconButton(
                        tooltip: context.tr('Login QR'),
                        onPressed: () => _showLoginQr(t),
                        icon: const Icon(Icons.qr_code_2),
                      ),
                      if (t.status == 'suspended')
                        IconButton(
                          tooltip: context.tr('Activate User'),
                          onPressed: () async {
                            try {
                              await Supabase.instance.client.rpc('activate_user', params: {'user_uid': t.profileId});
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teacher activated')));
                                _loadTeachers();
                              }
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                        )
                      else
                        IconButton(
                          tooltip: context.tr('Suspend User'),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Suspend Teacher'),
                                content: const Text('Are you sure you want to suspend this teacher?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Suspend', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await Supabase.instance.client.rpc('suspend_user', params: {'user_uid': t.profileId});
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teacher suspended')));
                                  _loadTeachers();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.block, color: Colors.red),
                        ),
                      IconButton(
                        tooltip: context.tr('Edit Teacher'),
                        onPressed: () => _showEditTeacherDialog(t),
                        icon: const Icon(Icons.edit, color: Colors.blue),
                      ),
                      IconButton(
                        tooltip: context.tr('Delete Teacher'),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Teacher'),
                              content: const Text('Are you sure you want to permanently delete this teacher?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true), 
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await Supabase.instance.client.rpc('hard_delete_user', params: {'target_user_id': t.profileId});
                              _loadTeachers();
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
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
