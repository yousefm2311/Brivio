import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/notification.dart';
import '../../domain/repositories/i_notification_repository.dart';

class SupabaseNotificationRepository implements INotificationRepository {
  final SupabaseClientWrapper _clientWrapper;
  RealtimeChannel? _notificationChannel;

  SupabaseNotificationRepository(this._clientWrapper);

  @override
  Future<List<AppNotification>> getNotifications() async {
    final currUser = _clientWrapper.client.auth.currentUser;
    if (currUser == null) return [];

    final response = await _clientWrapper.client
        .from('app_notifications')
        .select()
        .eq('user_id', currUser.id)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> getUnreadCount() async {
    final currUser = _clientWrapper.client.auth.currentUser;
    if (currUser == null) return 0;

    final response = await _clientWrapper.client
        .from('app_notifications')
        .select('id')
        .eq('user_id', currUser.id)
        .eq('is_read', false);

    return (response as List<dynamic>).length;
  }

  @override
  Future<void> markRead(String notificationId) async {
    final currUser = _clientWrapper.client.auth.currentUser;
    if (currUser == null) return;

    await _clientWrapper.client
        .from('app_notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', currUser.id);
  }

  @override
  Future<void> markAllRead() async {
    final currUser = _clientWrapper.client.auth.currentUser;
    if (currUser == null) return;

    await _clientWrapper.client
        .from('app_notifications')
        .update({'is_read': true})
        .eq('user_id', currUser.id)
        .eq('is_read', false);
  }

  @override
  Future<NotificationPreference> getPreferences() async {
    final currUser = _clientWrapper.client.auth.currentUser;
    if (currUser == null) throw Exception('Unauthenticated');

    final response = await _clientWrapper.client
        .from('notification_preferences')
        .select()
        .eq('user_id', currUser.id)
        .maybeSingle();

    if (response == null) {
      return NotificationPreference(
        userId: currUser.id,
        updatedAt: DateTime.now(),
      );
    }
    return NotificationPreference.fromJson(response);
  }

  @override
  Future<void> updatePreferences(NotificationPreference preference) async {
    await _clientWrapper.client
        .from('notification_preferences')
        .upsert(preference.toJson());
  }

  @override
  Stream<AppNotification> subscribeToNotifications() {
    final controller = StreamController<AppNotification>.broadcast();
    final currUser = _clientWrapper.client.auth.currentUser;
    if (currUser == null) return controller.stream;

    if (_notificationChannel != null) {
      _clientWrapper.client.removeChannel(_notificationChannel!);
    }

    _notificationChannel = _clientWrapper.client.channel(
      'notifications:${currUser.id}',
    );

    _notificationChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'app_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: currUser.id,
          ),
          callback: (payload) {
            if (!controller.isClosed) {
              controller.add(AppNotification.fromJson(payload.newRecord));
            }
          },
        )
        .subscribe();

    return controller.stream;
  }

  @override
  void clearCache() {
    if (_notificationChannel != null) {
      _clientWrapper.client.removeChannel(_notificationChannel!);
      _notificationChannel = null;
    }
  }
}
