import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../viewmodels/notification_center_viewmodel.dart';

class NotificationCenterScreen extends StatefulWidget {
  final NotificationCenterViewModel viewModel;

  const NotificationCenterScreen({super.key, required this.viewModel});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('Notifications')),
            actions: [
              if (vm.notifications.any((n) => !n.isRead))
                TextButton(
                  onPressed: vm.markAllRead,
                  child: Text(
                    context.tr('Mark All Read'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          body: vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : vm.errorMessage != null
              ? Center(
                  child: Text(
                    '${context.tr('Error')}: ${vm.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : vm.notifications.isEmpty
              ? Center(
                  child: Text(
                    context.tr('No notifications in your inbox.'),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: vm.loadNotifications,
                  child: ListView.separated(
                    itemCount: vm.notifications.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notif = vm.notifications[index];

                      return ListTile(
                        tileColor: notif.isRead
                            ? Colors.white
                            : Colors.blue.shade50,
                        leading: CircleAvatar(
                          backgroundColor: notif.isRead
                              ? Colors.grey.shade200
                              : Colors.blue.shade100,
                          child: Icon(
                            Icons.notifications,
                            color: notif.isRead ? Colors.grey : Colors.blue,
                          ),
                        ),
                        title: Text(
                          notif.title,
                          style: TextStyle(
                            fontWeight: notif.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(notif.message),
                        trailing: Text(
                          '${notif.createdAt.hour}:${notif.createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        onTap: () {
                          if (!notif.isRead) {
                            vm.markRead(notif.id);
                          }
                          final pushService =
                              GetIt.instance.isRegistered<PushNotificationService>()
                                  ? GetIt.instance<PushNotificationService>()
                                  : PushNotificationService(
                                    GetIt.instance<SupabaseClientWrapper>(),
                                  );
                          pushService.handleNotificationTap({
                            'type': notif.type,
                            'reference_id': notif.referenceId,
                            'id': notif.id,
                            'title': notif.title,
                            'message': notif.message,
                          });
                        },
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
