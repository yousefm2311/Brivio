import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/notification.dart';
import '../../domain/repositories/i_notification_repository.dart';

class NotificationCenterViewModel extends ChangeNotifier {
  final INotificationRepository _notificationRepository;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _unreadCount = 0;
  StreamSubscription<AppNotification>? _subscription;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _unreadCount;

  NotificationCenterViewModel(this._notificationRepository);

  Future<void> loadNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notifications = await _notificationRepository.getNotifications();
      _unreadCount = await _notificationRepository.getUnreadCount();
      _subscribeRealtime();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeRealtime() {
    _subscription?.cancel();
    _subscription = _notificationRepository.subscribeToNotifications().listen((
      notification,
    ) {
      _notifications.insert(0, notification);
      _unreadCount++;
      notifyListeners();
    });
  }

  Future<void> markRead(String notificationId) async {
    try {
      await _notificationRepository.markRead(notificationId);
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx >= 0 && !_notifications[idx].isRead) {
        _notifications[idx] = _notifications[idx].copyWith(
          isRead: true,
        );
        if (_unreadCount > 0) _unreadCount--;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    try {
      await _notificationRepository.markAllRead();
      _notifications = _notifications
          .map((n) => n.isRead ? n : n.copyWith(isRead: true))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearState() {
    _subscription?.cancel();
    _notifications = [];
    _unreadCount = 0;
    _errorMessage = null;
    _notificationRepository.clearCache();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
