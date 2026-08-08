import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RbacManagementScreen extends StatefulWidget {
  const RbacManagementScreen({super.key});

  @override
  State<RbacManagementScreen> createState() => _RbacManagementScreenState();
}

class _RbacManagementScreenState extends State<RbacManagementScreen> {
  List<Map<String, dynamic>> _permissions = [];
  List<Map<String, dynamic>> _roles = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRbacData();
  }

  Future<void> _loadRbacData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pRes = await Supabase.instance.client
          .from('permissions')
          .select()
          .order('module');
      final rRes = await Supabase.instance.client
          .from('roles')
          .select()
          .order('name');

      if (mounted) {
        setState(() {
          _permissions = (pRes as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _roles = (rRes as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('RBAC Security Governance & Permissions Inspector'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.security), text: 'Permissions Catalog'),
              Tab(icon: Icon(Icons.admin_panel_settings), text: 'System Roles'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadRbacData,
            ),
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
                      onPressed: _loadRbacData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : TabBarView(
                children: [
                  // Tab 1: Permissions Catalog
                  _permissions.isEmpty
                      ? const Center(
                          child: Text('No system permissions found.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _permissions.length,
                          separatorBuilder: (ctx, i) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final p = _permissions[i];
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.lock_open),
                              ),
                              title: Text(
                                p['code'] as String? ?? 'permission.code',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Module: ${(p['module'] as String? ?? "core").toUpperCase()} | Action: ${p['action']}',
                              ),
                              trailing: Chip(
                                label: const Text('ENFORCED'),
                                backgroundColor: Colors.blue.shade100,
                              ),
                            );
                          },
                        ),
                  // Tab 2: System Roles
                  _roles.isEmpty
                      ? const Center(child: Text('No system roles found.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _roles.length,
                          separatorBuilder: (ctx, i) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final r = _roles[i];
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.admin_panel_settings),
                              ),
                              title: Text(
                                (r['name'] as String? ?? 'role').toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                (r['description'] as String?) ?? 'System Role',
                              ),
                              trailing: const Icon(
                                Icons.verified_user,
                                color: Colors.green,
                              ),
                            );
                          },
                        ),
                ],
              ),
      ),
    );
  }
}
