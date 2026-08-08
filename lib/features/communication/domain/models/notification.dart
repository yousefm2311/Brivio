class AppNotification {
  final String id;
  final String userId;
  final String notificationType;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime? archivedAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.notificationType,
    required this.title,
    required this.body,
    this.data = const {},
    this.readAt,
    this.archivedAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      notificationType: json['notification_type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : {},
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'notification_type': notificationType,
      'title': title,
      'body': body,
      'data': data,
      'read_at': readAt?.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({DateTime? readAt, DateTime? archivedAt}) {
    return AppNotification(
      id: id,
      userId: userId,
      notificationType: notificationType,
      title: title,
      body: body,
      data: data,
      readAt: readAt ?? this.readAt,
      archivedAt: archivedAt ?? this.archivedAt,
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
