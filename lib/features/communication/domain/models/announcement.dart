enum AnnouncementStatus { draft, scheduled, published, archived }

enum AnnouncementPriority { normal, important, urgent }

class AnnouncementTarget {
  final String id;
  final String announcementId;
  final String targetType; // 'all', 'branch', 'role', 'academic_group', 'user'
  final String? targetId;

  const AnnouncementTarget({
    required this.id,
    required this.announcementId,
    required this.targetType,
    this.targetId,
  });

  factory AnnouncementTarget.fromJson(Map<String, dynamic> json) {
    return AnnouncementTarget(
      id: json['id'] as String,
      announcementId: json['announcement_id'] as String,
      targetType: json['target_type'] as String,
      targetId: json['target_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'announcement_id': announcementId,
      'target_type': targetType,
      'target_id': targetId,
    };
  }
}

class Announcement {
  final String id;
  final String title;
  final String body;
  final AnnouncementStatus status;
  final AnnouncementPriority priority;
  final DateTime publishAt;
  final DateTime? expiresAt;
  final bool requiresAcknowledgement;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AnnouncementTarget> targets;
  final DateTime? readAt;
  final DateTime? acknowledgedAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.status = AnnouncementStatus.published,
    this.priority = AnnouncementPriority.normal,
    required this.publishAt,
    this.expiresAt,
    this.requiresAcknowledgement = false,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.targets = const [],
    this.readAt,
    this.acknowledgedAt,
  });

  bool get isRead => readAt != null;
  bool get isAcknowledged => acknowledgedAt != null;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final targetsJson = json['announcement_targets'] as List<dynamic>?;
    final parsedTargets = targetsJson != null
        ? targetsJson
              .map(
                (t) => AnnouncementTarget.fromJson(t as Map<String, dynamic>),
              )
              .toList()
        : <AnnouncementTarget>[];

    final readsJson = json['announcement_reads'] as List<dynamic>?;
    DateTime? parsedReadAt;
    DateTime? parsedAckAt;
    if (readsJson != null && readsJson.isNotEmpty) {
      final rd = readsJson.first as Map<String, dynamic>;
      if (rd['read_at'] != null) {
        parsedReadAt = DateTime.parse(rd['read_at'] as String);
      }
      if (rd['acknowledged_at'] != null) {
        parsedAckAt = DateTime.parse(rd['acknowledged_at'] as String);
      }
    }

    final stStr = (json['status'] as String?) ?? 'published';
    AnnouncementStatus st = AnnouncementStatus.published;
    if (stStr == 'draft') st = AnnouncementStatus.draft;
    if (stStr == 'scheduled') st = AnnouncementStatus.scheduled;
    if (stStr == 'archived') st = AnnouncementStatus.archived;

    final prStr = (json['priority'] as String?) ?? 'normal';
    AnnouncementPriority pr = AnnouncementPriority.normal;
    if (prStr == 'important') pr = AnnouncementPriority.important;
    if (prStr == 'urgent') pr = AnnouncementPriority.urgent;

    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      status: st,
      priority: pr,
      publishAt: DateTime.parse(json['publish_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      requiresAcknowledgement: json['requires_acknowledgement'] == true,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      targets: parsedTargets,
      readAt: parsedReadAt,
      acknowledgedAt: parsedAckAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'status': status.name,
      'priority': priority.name,
      'publish_at': publishAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'requires_acknowledgement': requiresAcknowledgement,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Announcement copyWith({
    DateTime? readAt,
    DateTime? acknowledgedAt,
    AnnouncementStatus? status,
  }) {
    return Announcement(
      id: id,
      title: title,
      body: body,
      status: status ?? this.status,
      priority: priority,
      publishAt: publishAt,
      expiresAt: expiresAt,
      requiresAcknowledgement: requiresAcknowledgement,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      targets: targets,
      readAt: readAt ?? this.readAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    );
  }
}
