import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';

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
        title: const Text('Provision New Parent Account'),
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
            child: const Text('Provision Parent'),
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
                  decoration: const InputDecoration(
                    labelText: 'Select Child / Student',
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
                decoration: const InputDecoration(
                  labelText: 'Relationship Type',
                ),
                items: const [
                  DropdownMenuItem(value: 'father', child: Text('Father')),
                  DropdownMenuItem(value: 'mother', child: Text('Mother')),
                  DropdownMenuItem(value: 'guardian', child: Text('Guardian')),
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
              child: const Text('Cancel'),
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
              child: const Text('Link Child'),
            ),
          ],
        ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadParents),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showProvisionParentDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Provision Parent'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Parents',
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
                          onPressed: _loadParents,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : filtered.isEmpty
                ? const Center(child: Text('No parents found.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final p = filtered[i];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.family_restroom),
                        ),
                        title: Text(
                          p.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Email: ${p.email}'),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _showLinkStudentDialog(p),
                          icon: const Icon(Icons.link, size: 16),
                          label: const Text('Link Child'),
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
