import 'package:flutter/material.dart';
import '../viewmodels/announcement_viewmodel.dart';

class AnnouncementCenterScreen extends StatefulWidget {
  final AnnouncementViewModel viewModel;

  const AnnouncementCenterScreen({super.key, required this.viewModel});

  @override
  State<AnnouncementCenterScreen> createState() =>
      _AnnouncementCenterScreenState();
}

class _AnnouncementCenterScreenState extends State<AnnouncementCenterScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.loadTargetedAnnouncements();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;

        return Scaffold(
          appBar: AppBar(title: const Text('Announcements')),
          body: vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : vm.errorMessage != null
              ? Center(
                  child: Text(
                    'Error: ${vm.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : vm.announcements.isEmpty
              ? const Center(
                  child: Text(
                    'No announcements for your targeted group.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: vm.loadTargetedAnnouncements,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: vm.announcements.length,
                    itemBuilder: (context, index) {
                      final ann = vm.announcements[index];
                      final isUrgent = ann.priority.name == 'urgent';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: isUrgent ? 4 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isUrgent
                              ? const BorderSide(color: Colors.red, width: 1.5)
                              : BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isUrgent) ...[
                                    const Icon(
                                      Icons.warning,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: Text(
                                      ann.title,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isUrgent
                                            ? Colors.red.shade900
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      ann.priority.name.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: isUrgent
                                        ? Colors.red
                                        : Colors.blue,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ann.body,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Published: ${ann.publishAt.year}-${ann.publishAt.month}-${ann.publishAt.day}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (ann.requiresAcknowledgement)
                                    ann.isAcknowledged
                                        ? const Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 16,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Acknowledged',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          )
                                        : ElevatedButton(
                                            onPressed: () =>
                                                vm.acknowledgeAnnouncement(
                                                  ann.id,
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                            ),
                                            child: const Text('I Acknowledge'),
                                          ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
