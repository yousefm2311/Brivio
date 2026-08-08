import 'package:flutter/material.dart';
import '../../domain/models/announcement.dart';
import '../viewmodels/announcement_management_viewmodel.dart';

class AnnouncementManagementScreen extends StatefulWidget {
  final AnnouncementManagementViewModel viewModel;

  const AnnouncementManagementScreen({super.key, required this.viewModel});

  @override
  State<AnnouncementManagementScreen> createState() =>
      _AnnouncementManagementScreenState();
}

class _AnnouncementManagementScreenState
    extends State<AnnouncementManagementScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  AnnouncementPriority _priority = AnnouncementPriority.normal;
  bool _requiresAck = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.loadAdminAnnouncements();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Create Announcement'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextField(
                      controller: _bodyController,
                      decoration: const InputDecoration(labelText: 'Body'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AnnouncementPriority>(
                      initialValue: _priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: AnnouncementPriority.values
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setStateDialog(() => _priority = val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Requires Acknowledgement'),
                      value: _requiresAck,
                      onChanged: (val) =>
                          setStateDialog(() => _requiresAck = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_titleController.text.trim().isEmpty ||
                        _bodyController.text.trim().isEmpty) {
                      return;
                    }

                    final nav = Navigator.of(context);
                    final success = await widget.viewModel.createAnnouncement(
                      title: _titleController.text.trim(),
                      body: _bodyController.text.trim(),
                      priority: _priority,
                      publishAt: DateTime.now(),
                      requiresAcknowledgement: _requiresAck,
                      targets: [
                        const AnnouncementTarget(
                          id: '',
                          announcementId: '',
                          targetType: 'all',
                        ),
                      ],
                    );

                    if (success) {
                      _titleController.clear();
                      _bodyController.clear();
                      nav.pop();
                    }
                  },
                  child: const Text('Save Draft'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;

        return Scaffold(
          appBar: AppBar(title: const Text('Announcement Management')),
          floatingActionButton: FloatingActionButton(
            onPressed: _showCreateDialog,
            child: const Icon(Icons.add),
          ),
          body: vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : vm.errorMessage != null
              ? Center(
                  child: Text(
                    'Error: ${vm.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : vm.adminAnnouncements.isEmpty
              ? const Center(child: Text('No announcements found.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: vm.adminAnnouncements.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ann = vm.adminAnnouncements[index];
                    final isDraft = ann.status == AnnouncementStatus.draft;

                    return Card(
                      child: ListTile(
                        title: Text(
                          ann.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${ann.body}\nStatus: ${ann.status.name.toUpperCase()}',
                        ),
                        trailing: isDraft
                            ? ElevatedButton(
                                onPressed: () => vm.publishAnnouncement(ann.id),
                                child: const Text('Publish'),
                              )
                            : const Chip(
                                label: Text(
                                  'PUBLISHED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                                backgroundColor: Colors.green,
                              ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
