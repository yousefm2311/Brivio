class AdminSetting {
  final String key;
  final dynamic value;
  final DateTime updatedAt;

  AdminSetting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  factory AdminSetting.fromJson(Map<String, dynamic> json) {
    return AdminSetting(
      key: json['key'],
      value: json['value'],
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class AdminRole {
  final String id;
  final String name;
  final List<String> permissions;

  AdminRole({
    required this.id,
    required this.name,
    required this.permissions,
  });

  factory AdminRole.fromJson(Map<String, dynamic> json) {
    return AdminRole(
      id: json['id'],
      name: json['name'],
      permissions: List<String>.from(json['permissions'] ?? []),
    );
  }
}

class AdminAnalytics {
  final double totalRevenue;
  final double attendanceRate;
  final int totalStudents;
  final int totalSessions;

  AdminAnalytics({
    required this.totalRevenue,
    required this.attendanceRate,
    required this.totalStudents,
    required this.totalSessions,
  });

  factory AdminAnalytics.fromJson(Map<String, dynamic> json) {
    return AdminAnalytics(
      totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
      attendanceRate: (json['attendance_rate'] ?? 0).toDouble(),
      totalStudents: json['total_students'] ?? 0,
      totalSessions: json['total_sessions'] ?? 0,
    );
  }
}

class HelpdeskTicket {
  final String id;
  final String userId;
  final String subject;
  final String description;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  HelpdeskTicket({
    required this.id,
    required this.userId,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HelpdeskTicket.fromJson(Map<String, dynamic> json) {
    return HelpdeskTicket(
      id: json['id'],
      userId: json['user_id'],
      subject: json['subject'],
      description: json['description'],
      status: json['status'],
      priority: json['priority'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
