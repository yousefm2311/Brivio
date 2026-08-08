import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';

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

  void _showProvisionStaffDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String targetRole = 'staff';
    String? selectedBranchId = _branches.isNotEmpty ? _branches.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Provision Staff / Admin Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                  keyboardType: TextInputType.emailAddress,
                ),
                DropdownButtonFormField<String>(
                  initialValue: targetRole,
                  decoration: const InputDecoration(labelText: 'Target Role'),
                  items: const [
                    DropdownMenuItem(
                      value: 'staff',
                      child: Text('Operations Staff'),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Branch Admin'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setStateDialog(() => targetRole = v);
                  },
                ),
                if (_branches.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedBranchId,
                    decoration: const InputDecoration(
                      labelText: 'Branch Assignment',
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
              child: const Text('Cancel'),
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
                          'role': targetRole,
                          if (selectedBranchId != null)
                            'branchId': selectedBranchId,
                        },
                      );

                  if (response.status != 200) {
                    final err = response.data is Map
                        ? response.data['error']
                        : 'Provisioning failed';
                    throw Exception(err ?? 'Status ${response.status}');
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
                        content: Text('Provisioning error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Provision Account'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff & Admin Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStaff),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showProvisionStaffDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Provision Staff'),
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
                    onPressed: _loadStaff,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _staffProfiles.isEmpty
          ? const Center(child: Text('No staff or admin accounts found.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _staffProfiles.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final p = _staffProfiles[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.badge)),
                  title: Text(
                    (p['full_name'] as String?) ?? 'Staff Member',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Email: ${p['email']} | Role: ${(p['role'] as String? ?? "staff").toUpperCase()}',
                  ),
                  trailing: Chip(
                    label: Text(
                      (p['status'] as String? ?? "active").toUpperCase(),
                    ),
                    backgroundColor: Colors.blue.shade100,
                  ),
                );
              },
            ),
    );
  }
}
