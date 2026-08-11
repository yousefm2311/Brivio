import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../widgets/account_login_qr_dialog.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  late final SupabaseStudentRepository _studentRepo;
  late final SupabaseBranchRepository _branchRepo;

  List<Student> _students = [];
  List<Branch> _branches = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _branchRepo = SupabaseBranchRepository(wrapper);
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _studentRepo.fetchStudents();
      final bRes = await _branchRepo.fetchBranches();
      if (mounted) {
        setState(() {
          _students = res.data;
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

  void _showEditStudentDialog(Student student) {
    final nameCtrl = TextEditingController(text: student.fullName);
    final codeCtrl = TextEditingController(text: student.studentCode);
    String? selectedBranchId = student.primaryBranchId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(context.tr('Edit Student')),
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
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Student Code'),
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
                if (nameCtrl.text.trim().isEmpty) return;

                final nav = Navigator.of(ctx);
                try {
                  await Supabase.instance.client
                      .from('profiles')
                      .update({'full_name': nameCtrl.text.trim()})
                      .eq('id', student.profileId);
                  
                  await Supabase.instance.client
                      .from('students')
                      .update({
                        'student_code': codeCtrl.text.trim(),
                        if (selectedBranchId != null) 'primary_branch_id': selectedBranchId,
                      })
                      .eq('id', student.id);

                  nav.pop();
                  _loadStudents();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Student updated successfully!'),
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

  void _showProvisionStudentDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String? selectedBranchId = _branches.isNotEmpty ? _branches.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(context.tr('Provision New Student Account')),
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
                      'p_role': 'student',
                      if (selectedBranchId != null)
                        'p_branch_id': selectedBranchId,
                    },
                  );

                  if (response == null || (response is Map && response['success'] != true)) {
                    throw Exception('Provisioning failed.');
                  }

                  nav.pop();
                  _loadStudents();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Student provisioned with invite email sent!',
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
              child: Text(context.tr('Provision Student')),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginQr(Student student) {
    showDialog(
      context: context,
      builder: (_) => AccountLoginQrDialog(
        profileId: student.profileId,
        displayName: student.fullName,
        email: student.email,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _students.where((s) {
      final q = _searchController.text.toLowerCase();
      return s.fullName.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.studentCode.toLowerCase().contains(q);
    }).toList();

    return PortalPageShell(
      title: 'Student Management',
      subtitle:
          'Provision student accounts and review academy enrollment data.',
      icon: Icons.school,
      accentColor: AppColors.studentRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'Refresh',
          onPressed: _loadStudents,
        ),
        PortalAction(
          icon: Icons.person_add,
          label: 'Provision Student',
          onPressed: _showProvisionStudentDialog,
          primary: true,
        ),
      ],
      child: Column(
        children: [
          PortalSearchField(
            controller: _searchController,
            label: 'Search students',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: 'No students found',
              emptySubtitle:
                  'Provision students from here after branches exist.',
              emptyIcon: Icons.school,
              onRetry: _loadStudents,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final s = filtered[i];
                  return PortalListCard(
                    icon: Icons.school,
                    accentColor: AppColors.studentRole,
                    title: s.fullName,
                    subtitle:
                        '${context.tr('Code')}: ${s.studentCode} | ${context.tr('Email')}: ${s.email}',
                    trailing: [
                      IconButton(
                        tooltip: context.tr('Login QR'),
                        onPressed: () => _showLoginQr(s),
                        icon: const Icon(Icons.qr_code_2),
                      ),
                      if (s.status == 'suspended')
                        IconButton(
                          tooltip: context.tr('Activate Student'),
                          onPressed: () async {
                            try {
                              await Supabase.instance.client.rpc('activate_user', params: {'user_uid': s.profileId});
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student activated')));
                                _loadStudents();
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
                                title: const Text('Suspend Student'),
                                content: const Text('Are you sure you want to suspend this student?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Suspend', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await Supabase.instance.client.rpc('suspend_user', params: {'user_uid': s.profileId});
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student suspended')));
                                  _loadStudents();
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
                        tooltip: context.tr('Edit Student'),
                        onPressed: () => _showEditStudentDialog(s),
                        icon: const Icon(Icons.edit, color: Colors.blue),
                      ),
                      IconButton(
                        tooltip: context.tr('Delete Student'),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Student'),
                              content: const Text('Are you sure you want to permanently delete this student?'),
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
                              await Supabase.instance.client.rpc('hard_delete_user', params: {'target_user_id': s.profileId});
                              _loadStudents();
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                      PortalStatusChip(status: s.status),
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
