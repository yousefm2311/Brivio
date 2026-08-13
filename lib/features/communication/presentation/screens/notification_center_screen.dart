import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: backgroundColor,
            surfaceTintColor: Colors.transparent,
            title: Text(context.tr('Notifications')),
            actions: [
              if (vm.notifications.any((n) => !n.isRead))
                TextButton(
                  onPressed: vm.markAllRead,
                  child: Text(context.tr('Mark All Read')),
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
                    style: AppTypography.bodyMedium(textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: vm.loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: vm.notifications.length,
                    itemBuilder: (context, index) {
                      final notif = vm.notifications[index];
                      final accent = notif.isRead
                          ? AppColors.info
                          : AppColors.warning;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          padding: EdgeInsets.zero,
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                          borderColor: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          child: InkWell(
                            onTap: () {
                              if (!notif.isRead) {
                                vm.markRead(notif.id);
                              }
                              final pushService =
                                  GetIt.instance
                                      .isRegistered<PushNotificationService>()
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
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      notif.isRead
                                          ? Icons.notifications_none_rounded
                                          : Icons.notifications_active_rounded,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notif.title,
                                          style:
                                              AppTypography.titleSmall(
                                                textPrimary,
                                              ).copyWith(
                                                fontWeight: notif.isRead
                                                    ? FontWeight.w600
                                                    : FontWeight.w800,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          notif.message,
                                          style: AppTypography.bodySmall(
                                            textSecondary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatNotificationTime(
                                            notif.createdAt,
                                          ),
                                          style: AppTypography.caption(
                                            textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!notif.isRead) ...[
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppColors.warning,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
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

String _formatNotificationTime(DateTime createdAt) {
  final hour = createdAt.hour.toString().padLeft(2, '0');
  final minute = createdAt.minute.toString().padLeft(2, '0');
  final month = createdAt.month.toString().padLeft(2, '0');
  final day = createdAt.day.toString().padLeft(2, '0');
  return '${createdAt.year}-$month-$day  $hour:$minute';
}
