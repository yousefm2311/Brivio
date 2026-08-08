import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';

class TeacherHomeworkScreen extends StatefulWidget {
  final String teacherId;

  const TeacherHomeworkScreen({super.key, required this.teacherId});

  @override
  State<TeacherHomeworkScreen> createState() => _TeacherHomeworkScreenState();
}

class _TeacherHomeworkScreenState extends State<TeacherHomeworkScreen> {
  late final SupabaseHomeworkRepository _homeworkRepo;
  List<Homework> _homeworks = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _homeworkRepo = SupabaseHomeworkRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _loadHomeworks();
  }

  Future<void> _loadHomeworks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final h = await _homeworkRepo.fetchHomeworkForGroup(
        'c1000000-0000-0000-0000-000000000001',
      );
      if (mounted) {
        setState(() {
          _homeworks = h;
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

  void _showCreateHomeworkDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ptsCtrl = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create & Publish Homework for Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Homework Title (e.g. CS-101 Assignment 1)',
                ),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instructions / Description',
                ),
                maxLines: 2,
              ),
              TextField(
                controller: ptsCtrl,
                decoration: const InputDecoration(labelText: 'Max Score'),
                keyboardType: TextInputType.number,
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
              if (titleCtrl.text.trim().isEmpty) return;

              final nav = Navigator.of(ctx);
              try {
                await Supabase.instance.client.rpc(
                  'create_homework_assignment',
                  params: {
                    'p_title': titleCtrl.text.trim(),
                    'p_description': descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                    'p_subject_id': '30000000-0000-0000-0000-000000000001',
                    'p_group_id': 'c1000000-0000-0000-0000-000000000001',
                    'p_due_at': DateTime.now()
                        .add(const Duration(days: 7))
                        .toIso8601String(),
                    'p_max_score': double.tryParse(ptsCtrl.text) ?? 100.0,
                    'p_status': 'published',
                  },
                );
                nav.pop();
                _loadHomeworks();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Homework assignment published to enrolled students!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Creation failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Publish Homework'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Homework Workspace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHomeworks,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateHomeworkDialog,
        icon: const Icon(Icons.assignment),
        label: const Text('Create Homework'),
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
                    onPressed: _loadHomeworks,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _homeworks.isEmpty
          ? const Center(child: Text('No homework assignments published yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _homeworks.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final h = _homeworks[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.assignment)),
                  title: Text(
                    h.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Max Score: ${h.maxScore} | Due: ${h.dueAt.year}-${h.dueAt.month}-${h.dueAt.day} | Status: ${h.status.toUpperCase()}',
                  ),
                );
              },
            ),
    );
  }
}
