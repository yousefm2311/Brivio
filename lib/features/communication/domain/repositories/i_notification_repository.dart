import '../models/notification.dart';

abstract class INotificationRepository {
  Future<List<AppNotification>> getNotifications();
  Future<int> getUnreadCount();
  Future<void> markRead(String notificationId);
  Future<void> markAllRead();
  Future<NotificationPreference> getPreferences();
  Future<void> updatePreferences(NotificationPreference preference);
  Stream<AppNotification> subscribeToNotifications();
  void clearCache();
}
