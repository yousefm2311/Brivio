import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';
import 'teacher_group_details_screen.dart';

class TeacherGroupsScreen extends StatefulWidget {
  final String teacherId;

  const TeacherGroupsScreen({super.key, required this.teacherId});

  @override
  State<TeacherGroupsScreen> createState() => _TeacherGroupsScreenState();
}

class _TeacherGroupsScreenState extends State<TeacherGroupsScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  List<GroupEntity> _groups = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      if (mounted) {
        setState(() {
          _groups = res;
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

  void _openGroupDetails(GroupEntity group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherGroupDetailsScreen(group: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assigned Groups'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadGroups),
        ],
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
                    onPressed: _loadGroups,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _groups.isEmpty
          ? const Center(child: Text('No groups currently assigned to you.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _groups.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final g = _groups[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.group)),
                  title: Text(
                    g.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Code: ${g.code} | Capacity: ${g.maxCapacity ?? "Unlimited"}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openGroupDetails(g),
                );
              },
            ),
    );
  }
}
