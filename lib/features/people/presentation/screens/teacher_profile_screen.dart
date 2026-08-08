import 'package:flutter/material.dart';
import '../../../../features/auth/presentation/viewmodels/auth_viewmodel.dart';

class TeacherProfileScreen extends StatelessWidget {
  final AuthViewModel authViewModel;

  const TeacherProfileScreen({super.key, required this.authViewModel});

  @override
  Widget build(BuildContext context) {
    final user = authViewModel.currentUser;
    final bootstrap = authViewModel.bootstrap;

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Account Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      child: Icon(Icons.person, size: 48),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.fullName ?? 'Educator Teacher',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'teacher@academy.com',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Chip(
                      label: Text(
                        'ROLE: ${(user?.role ?? "teacher").toString().toUpperCase()}',
                      ),
                      backgroundColor: Colors.purple.shade100,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Specifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.badge),
                      title: const Text('Teacher Domain ID'),
                      subtitle: Text(
                        bootstrap?.teacherId ??
                            '70000000-0000-0000-0000-000000000001',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.domain),
                      title: const Text('Primary Branch ID'),
                      subtitle: Text(
                        user?.branchId ??
                            '20000000-0000-0000-0000-000000000001',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.security),
                      title: const Text('Effective Permissions'),
                      subtitle: Text(
                        '${bootstrap?.effectivePermissions.length ?? 0} active system permissions',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => authViewModel.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
