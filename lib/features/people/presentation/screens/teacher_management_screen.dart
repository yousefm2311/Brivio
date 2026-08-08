import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';

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

  void _showProvisionTeacherDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String? selectedBranchId = _branches.isNotEmpty ? _branches.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Provision New Teacher Account'),
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
                          'role': 'teacher',
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
              child: const Text('Provision Teacher'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _teachers.where((t) {
      final q = _searchController.text.toLowerCase();
      return t.fullName.toLowerCase().contains(q) ||
          t.email.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTeachers),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showProvisionTeacherDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Provision Teacher'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Teachers',
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
                          onPressed: _loadTeachers,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : filtered.isEmpty
                ? const Center(child: Text('No teachers found.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final t = filtered[i];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(
                          t.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Email: ${t.email} | Specialization: ${t.specialization ?? "N/A"}',
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
