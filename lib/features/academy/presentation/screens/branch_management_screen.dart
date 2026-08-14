import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
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
        title: Text(context.tr('Create New Branch')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Branch Name (e.g. Nasr City)'),
                ),
              ),
              TextField(
                controller: codeCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Branch Code (e.g. NASR-01)'),
                ),
              ),
              TextField(
                controller: addrCtrl,
                decoration: InputDecoration(labelText: context.tr('Address')),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('Phone Number'),
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
                      content: Text(
                        '${context.tr('Failed to create branch')}: $e',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(context.tr('Create Branch')),
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
          title: Text('${context.tr('Edit Branch')} (${branch.code})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Branch Name'),
                  ),
                ),
                TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Branch Code'),
                  ),
                ),
                TextField(
                  controller: addrCtrl,
                  decoration: InputDecoration(labelText: context.tr('Address')),
                ),
                TextField(
                  controller: phoneCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('Phone Number'),
                  ),
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
                      SnackBar(
                        content: Text(
                          context.tr('Branch updated successfully!'),
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
                          '${context.tr('Failed to update branch')}: $e',
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
    final filtered = _branches.where((b) {
      final q = _searchController.text.toLowerCase();
      return b.name.toLowerCase().contains(q) ||
          b.code.toLowerCase().contains(q);
    }).toList();

    return PortalPageShell(
      title: 'Branch Management',
      subtitle: 'Create, edit, search, and archive academy branches.',
      icon: Icons.domain,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'Refresh',
          onPressed: _loadBranches,
        ),
        PortalAction(
          icon: Icons.add,
          label: 'Add Branch',
          onPressed: _showCreateBranchDialog,
          primary: true,
        ),
      ],
      child: Column(
        children: [
          PortalSearchField(
            controller: _searchController,
            label: 'Search branches',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: 'No branches found',
              emptySubtitle: 'Add the first branch or change your search.',
              emptyIcon: Icons.domain,
              onRetry: _loadBranches,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final b = filtered[i];
                  return PortalListCard(
                    icon: Icons.domain,
                    accentColor: AppColors.adminRole,
                    title: b.name,
                    subtitle:
                        'Code: ${b.code} | Address: ${b.address ?? "N/A"}',
                    trailing: [
                      PortalStatusChip(status: b.status),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditBranchDialog(b),
                        tooltip: 'Edit Branch',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Branch'),
                              content: const Text(
                                'Are you sure you want to delete this branch?',
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
                              await _branchRepo.deleteBranch(b.id);
                              _loadBranches();
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
                        tooltip: 'Delete Branch',
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
