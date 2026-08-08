import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  late final SupabaseBranchRepository _branchRepo;
  List<Branch> _branches = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _branchRepo = SupabaseBranchRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _loadBranches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _branchRepo.fetchBranches();
      if (mounted) {
        setState(() {
          _branches = res;
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

  void _showCreateBranchDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Branch'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Branch Name (e.g. Nasr City)',
                ),
              ),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Branch Code (e.g. NASR-01)',
                ),
              ),
              TextField(
                controller: addrCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number'),
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
                final b = Branch(
                  id: '',
                  code: codeCtrl.text.trim(),
                  name: nameCtrl.text.trim(),
                  address: addrCtrl.text.trim().isEmpty
                      ? null
                      : addrCtrl.text.trim(),
                  phoneNumber: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  status: 'active',
                );

                await _branchRepo.createBranch(b);
                nav.pop();
                _loadBranches();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to create branch: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create Branch'),
          ),
        ],
      ),
    );
  }

  void _showEditBranchDialog(Branch branch) {
    final nameCtrl = TextEditingController(text: branch.name);
    final codeCtrl = TextEditingController(text: branch.code);
    final addrCtrl = TextEditingController(text: branch.address ?? '');
    final phoneCtrl = TextEditingController(text: branch.phoneNumber ?? '');
    String status = branch.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Edit Branch (${branch.code})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Branch Name'),
                ),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Branch Code'),
                ),
                TextField(
                  controller: addrCtrl,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
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
                  final updated = Branch(
                    id: branch.id,
                    code: codeCtrl.text.trim(),
                    name: nameCtrl.text.trim(),
                    address: addrCtrl.text.trim().isEmpty
                        ? null
                        : addrCtrl.text.trim(),
                    phoneNumber: phoneCtrl.text.trim().isEmpty
                        ? null
                        : phoneCtrl.text.trim(),
                    status: status,
                  );

                  await _branchRepo.updateBranch(updated);
                  nav.pop();
                  _loadBranches();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Branch updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update branch: $e'),
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
    final filtered = _branches.where((b) {
      final q = _searchController.text.toLowerCase();
      return b.name.toLowerCase().contains(q) ||
          b.code.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branch Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBranches),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateBranchDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Branch'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Branches',
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
                          onPressed: _loadBranches,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : filtered.isEmpty
                ? const Center(child: Text('No branches found.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final b = filtered[i];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.domain)),
                        title: Text(
                          b.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Code: ${b.code} | Address: ${b.address ?? "N/A"}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(b.status.toUpperCase()),
                              backgroundColor: b.status == 'active'
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditBranchDialog(b),
                              tooltip: 'Edit Branch',
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
