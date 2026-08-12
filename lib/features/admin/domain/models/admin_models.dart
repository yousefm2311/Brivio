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
  final List<RevenueDataPoint> revenueGrowth;
  final List<SubjectPerformance> subjectPerformances;
  final StudentDemographics demographics;

  AdminAnalytics({
    required this.totalRevenue,
    required this.attendanceRate,
    required this.totalStudents,
    required this.totalSessions,
    required this.revenueGrowth,
    required this.subjectPerformances,
    required this.demographics,
  });

  factory AdminAnalytics.fromJson(Map<String, dynamic> json) {
    return AdminAnalytics(
      totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
      attendanceRate: (json['attendance_rate'] ?? 0).toDouble(),
      totalStudents: json['total_students'] ?? 0,
      totalSessions: json['total_sessions'] ?? 0,
      revenueGrowth: (json['revenue_growth'] as List<dynamic>?)
              ?.map((e) => RevenueDataPoint.fromJson(e))
              .toList() ??
          [],
      subjectPerformances: (json['subject_performances'] as List<dynamic>?)
              ?.map((e) => SubjectPerformance.fromJson(e))
              .toList() ??
          [],
      demographics: json['demographics'] != null
          ? StudentDemographics.fromJson(json['demographics'])
          : StudentDemographics(totalMales: 0, totalFemales: 0),
    );
  }
}

class RevenueDataPoint {
  final DateTime date;
  final double amount;

  RevenueDataPoint({required this.date, required this.amount});

  factory RevenueDataPoint.fromJson(Map<String, dynamic> json) {
    return RevenueDataPoint(
      date: DateTime.parse(json['date']),
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}

class SubjectPerformance {
  final String subjectName;
  final double averageScore;

  SubjectPerformance({required this.subjectName, required this.averageScore});

  factory SubjectPerformance.fromJson(Map<String, dynamic> json) {
    return SubjectPerformance(
      subjectName: json['subject_name'] ?? '',
      averageScore: (json['average_score'] ?? 0).toDouble(),
    );
  }
}

class StudentDemographics {
  final int totalMales;
  final int totalFemales;

  StudentDemographics({required this.totalMales, required this.totalFemales});
  
  double get malePercentage => (totalMales + totalFemales) == 0 ? 0 : totalMales / (totalMales + totalFemales);
  double get femalePercentage => (totalMales + totalFemales) == 0 ? 0 : totalFemales / (totalMales + totalFemales);

  factory StudentDemographics.fromJson(Map<String, dynamic> json) {
    return StudentDemographics(
      totalMales: json['total_males'] ?? 0,
      totalFemales: json['total_females'] ?? 0,
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
