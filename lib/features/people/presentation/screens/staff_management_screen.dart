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

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  late final SupabaseBranchRepository _branchRepo;
  List<Map<String, dynamic>> _staffProfiles = [];
  List<Branch> _branches = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _branchRepo = SupabaseBranchRepository(wrapper);
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .inFilter('role', ['staff', 'admin']);
      final bRes = await _branchRepo.fetchBranches();

      if (mounted) {
        setState(() {
          _staffProfiles = (res as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
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

  void _showEditStaffDialog(Map<String, dynamic> staff) {
    final nameCtrl = TextEditingController(
      text: staff['full_name'] as String? ?? '',
    );
    String targetRole = staff['role'] as String? ?? 'staff';
    if (targetRole != 'staff' && targetRole != 'admin') targetRole = 'staff';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(context.tr('Edit Staff')),
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
                DropdownButtonFormField<String>(
                  initialValue: targetRole,
                  decoration: InputDecoration(labelText: context.tr('Role')),
                  items: [
                    DropdownMenuItem(
                      value: 'staff',
                      child: Text(context.tr('Operations Staff')),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text(context.tr('Branch Admin')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setStateDialog(() => targetRole = v);
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
                if (nameCtrl.text.trim().isEmpty) return;

                final nav = Navigator.of(ctx);
                try {
                  await Supabase.instance.client
                      .from('profiles')
                      .update({
                        'full_name': nameCtrl.text.trim(),
                        'role': targetRole,
                      })
                      .eq('id', staff['id']);

                  nav.pop();
                  _loadStaff();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Staff updated successfully!'),
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

  void _showProvisionStaffDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String targetRole = 'staff';
    String? selectedBranchId = _branches.isNotEmpty ? _branches.first.id : null;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(context.tr('Provision Staff / Admin Account')),
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
                      'Leave empty if this account will set it after QR login.',
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
                DropdownButtonFormField<String>(
                  initialValue: targetRole,
                  decoration: InputDecoration(
                    labelText: context.tr('Target Role'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'staff',
                      child: Text(context.tr('Operations Staff')),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text(context.tr('Branch Admin')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setStateDialog(() => targetRole = v);
                  },
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
                          'role': targetRole,
                          'branchId': selectedBranchId,
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
                  _loadStaff();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Staff account provisioned successfully!',
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
                          'Provisioning error: ${_friendlyFunctionError(e)}',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(context.tr('Provision Account')),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyFunctionError(Object error) {
    final text = error.toString();
    if (text.contains('Requested function was not found') ||
        text.contains('status: 404')) {
      return 'Supabase function is not deployed yet. Deploy provision-user and try again.';
    }
    return text;
  }

  void _showLoginQr(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (_) => AccountLoginQrDialog(
        profileId: staff['id']?.toString() ?? '',
        displayName: staff['full_name']?.toString() ?? 'Staff Member',
        email: staff['email']?.toString() ?? '',
      ),
    );
  }

  void _showPasswordDialog(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (_) => AccountPasswordDialog(
        profileId: staff['id']?.toString() ?? '',
        displayName: staff['full_name']?.toString() ?? 'Staff Member',
        email: staff['email']?.toString() ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'Staff & Admin Management',
      subtitle: 'Provision operations staff and branch admin accounts.',
      icon: Icons.badge,
      accentColor: AppColors.info,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'Refresh',
          onPressed: _loadStaff,
        ),
        PortalAction(
          icon: Icons.person_add,
          label: 'Provision Staff',
          onPressed: _showProvisionStaffDialog,
          primary: true,
        ),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: _staffProfiles.isEmpty,
        emptyTitle: 'No staff accounts found',
        emptySubtitle: 'Provision staff or admin users from here.',
        emptyIcon: Icons.badge,
        onRetry: _loadStaff,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _staffProfiles.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final p = _staffProfiles[i];
            return PortalListCard(
              icon: Icons.badge,
              accentColor: AppColors.info,
              title: (p['full_name'] as String?) ?? 'Staff Member',
              subtitle:
                  '${context.tr('Email')}: ${p['email']} | ${context.tr('Role')}: ${context.l10n.t(p['role'] as String? ?? "staff").toUpperCase()}',
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
                if (p['status'] == 'suspended')
                  IconButton(
                    tooltip: context.tr('Activate Staff'),
                    onPressed: () async {
                      try {
                        await Supabase.instance.client.rpc(
                          'activate_user',
                          params: {'user_uid': p['id']},
                        );
                        _loadStaff();
                      } catch (err) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to activate: $err')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                  )
                else
                  IconButton(
                    tooltip: context.tr('Suspend Staff'),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Suspend Staff'),
                          content: const Text(
                            'Are you sure you want to suspend this staff member?',
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
                            params: {'user_uid': p['id']},
                          );
                          _loadStaff();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.block, color: Colors.orange),
                  ),
                IconButton(
                  tooltip: context.tr('Edit Staff'),
                  onPressed: () => _showEditStaffDialog(p),
                  icon: const Icon(Icons.edit, color: Colors.blue),
                ),
                IconButton(
                  tooltip: context.tr('Delete Staff'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Staff'),
                        content: const Text(
                          'Are you sure you want to permanently delete this staff member?',
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
                          params: {'target_user_id': p['id']},
                        );
                        _loadStaff();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                ),
                PortalStatusChip(status: (p['status'] as String? ?? "active")),
              ],
            );
          },
        ),
      ),
    );
  }
}
