class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.referenceId,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      referenceId: json['reference_id'] as String?,
      isRead: json['is_read'] == true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'reference_id': referenceId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      referenceId: referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

class NotificationPreference {
  final String userId;
  final bool inAppEnabled;
  final bool emailEnabled;
  final bool pushEnabled;
  final Map<String, bool> categories;
  final DateTime updatedAt;

  const NotificationPreference({
    required this.userId,
    this.inAppEnabled = true,
    this.emailEnabled = false,
    this.pushEnabled = false,
    this.categories = const {
      'chat': true,
      'announcements': true,
      'academic': true,
      'payments': true,
    },
    required this.updatedAt,
  });

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    final rawCat = json['categories'] as Map<String, dynamic>?;
    final catMap = <String, bool>{};
    if (rawCat != null) {
      rawCat.forEach((k, v) => catMap[k] = v == true);
    }

    return NotificationPreference(
      userId: json['user_id'] as String,
      inAppEnabled: json['in_app_enabled'] == true,
      emailEnabled: json['email_enabled'] == true,
      pushEnabled: json['push_enabled'] == true,
      categories: catMap.isEmpty
          ? {
              'chat': true,
              'announcements': true,
              'academic': true,
              'payments': true,
            }
          : catMap,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'in_app_enabled': inAppEnabled,
      'email_enabled': emailEnabled,
      'push_enabled': pushEnabled,
      'categories': categories,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
