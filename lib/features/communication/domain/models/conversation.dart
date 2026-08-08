enum ConversationType { direct, group }

class ConversationMember {
  final String id;
  final String conversationId;
  final String userId;
  final String memberRole;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final String? lastReadMessageId;
  final DateTime? lastReadAt;
  final DateTime? mutedUntil;
  final String? userFullName;
  final String? userEmail;
  final String? userAvatarUrl;

  const ConversationMember({
    required this.id,
    required this.conversationId,
    required this.userId,
    this.memberRole = 'member',
    required this.joinedAt,
    this.leftAt,
    this.lastReadMessageId,
    this.lastReadAt,
    this.mutedUntil,
    this.userFullName,
    this.userEmail,
    this.userAvatarUrl,
  });

  factory ConversationMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return ConversationMember(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      userId: json['user_id'] as String,
      memberRole: (json['member_role'] as String?) ?? 'member',
      joinedAt: DateTime.parse(json['joined_at'] as String),
      leftAt: json['left_at'] != null
          ? DateTime.parse(json['left_at'] as String)
          : null,
      lastReadMessageId: json['last_read_message_id'] as String?,
      lastReadAt: json['last_read_at'] != null
          ? DateTime.parse(json['last_read_at'] as String)
          : null,
      mutedUntil: json['muted_until'] != null
          ? DateTime.parse(json['muted_until'] as String)
          : null,
      userFullName: profile?['full_name'] as String?,
      userEmail: profile?['email'] as String?,
      userAvatarUrl: profile?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'user_id': userId,
      'member_role': memberRole,
      'joined_at': joinedAt.toIso8601String(),
      'left_at': leftAt?.toIso8601String(),
      'last_read_message_id': lastReadMessageId,
      'last_read_at': lastReadAt?.toIso8601String(),
      'muted_until': mutedUntil?.toIso8601String(),
    };
  }
}

class Conversation {
  final String id;
  final ConversationType conversationType;
  final String? title;
  final String? academicGroupId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastMessageAt;
  final DateTime? archivedAt;
  final List<ConversationMember> members;
  final String? lastMessageText;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.conversationType,
    this.title,
    this.academicGroupId,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessageAt,
    this.archivedAt,
    this.members = const [],
    this.lastMessageText,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    int unreadCount = 0,
  }) {
    final membersJson = json['conversation_members'] as List<dynamic>?;
    final parsedMembers = membersJson != null
        ? membersJson
              .map(
                (m) => ConversationMember.fromJson(m as Map<String, dynamic>),
              )
              .toList()
        : <ConversationMember>[];

    return Conversation(
      id: json['id'] as String,
      conversationType: json['conversation_type'] == 'group'
          ? ConversationType.group
          : ConversationType.direct,
      title: json['title'] as String?,
      academicGroupId: json['academic_group_id'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastMessageAt: DateTime.parse(
        (json['last_message_at'] ?? json['created_at']) as String,
      ),
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'] as String)
          : null,
      members: parsedMembers,
      lastMessageText: json['last_message_text'] as String?,
      unreadCount: unreadCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_type': conversationType == ConversationType.group
          ? 'group'
          : 'direct',
      'title': title,
      'academic_group_id': academicGroupId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_message_at': lastMessageAt.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
    };
  }

  Conversation copyWith({
    String? title,
    DateTime? lastMessageAt,
    String? lastMessageText,
    int? unreadCount,
    List<ConversationMember>? members,
  }) {
    return Conversation(
      id: id,
      conversationType: conversationType,
      title: title ?? this.title,
      academicGroupId: academicGroupId,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      archivedAt: archivedAt,
      members: members ?? this.members,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
