enum MessageType { text, attachment, system }

enum DeliveryStatus { sending, sent, failed }

class MessageAttachment {
  final String id;
  final String messageId;
  final String storagePath;
  final String originalName;
  final String mimeType;
  final int sizeBytes;
  final String uploadedBy;
  final DateTime createdAt;
  final String? signedUrl;

  const MessageAttachment({
    required this.id,
    required this.messageId,
    required this.storagePath,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedBy,
    required this.createdAt,
    this.signedUrl,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      storagePath: json['storage_path'] as String,
      originalName: json['original_name'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      uploadedBy: json['uploaded_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      signedUrl: json['signed_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'storage_path': storagePath,
      'original_name': originalName,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'uploaded_by': uploadedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  MessageAttachment copyWith({String? signedUrl}) {
    return MessageAttachment(
      id: id,
      messageId: messageId,
      storagePath: storagePath,
      originalName: originalName,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      uploadedBy: uploadedBy,
      createdAt: createdAt,
      signedUrl: signedUrl ?? this.signedUrl,
    );
  }
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final MessageType messageType;
  final String? textContent;
  final String? replyToMessageId;
  final DateTime sentAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? senderFullName;
  final String? senderAvatarUrl;
  final List<MessageAttachment> attachments;
  final DeliveryStatus deliveryStatus;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.messageType = MessageType.text,
    this.textContent,
    this.replyToMessageId,
    required this.sentAt,
    this.editedAt,
    this.deletedAt,
    this.senderFullName,
    this.senderAvatarUrl,
    this.attachments = const [],
    this.deliveryStatus = DeliveryStatus.sent,
  });

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null && deletedAt == null;

  factory Message.fromJson(Map<String, dynamic> json) {
    final senderProfile =
        json['sender'] as Map<String, dynamic>? ??
        json['profiles'] as Map<String, dynamic>?;
    final attJson = json['message_attachments'] as List<dynamic>?;
    final parsedAttachments = attJson != null
        ? attJson
              .map((a) => MessageAttachment.fromJson(a as Map<String, dynamic>))
              .toList()
        : <MessageAttachment>[];

    final mTypeStr = (json['message_type'] as String?) ?? 'text';
    MessageType mType = MessageType.text;
    if (mTypeStr == 'attachment') mType = MessageType.attachment;
    if (mTypeStr == 'system') mType = MessageType.system;

    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      messageType: mType,
      textContent: json['text_content'] as String?,
      replyToMessageId: json['reply_to_message_id'] as String?,
      sentAt: DateTime.parse(json['sent_at'] as String),
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      senderFullName: senderProfile?['full_name'] as String?,
      senderAvatarUrl: senderProfile?['avatar_url'] as String?,
      attachments: parsedAttachments,
      deliveryStatus: DeliveryStatus.sent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_type': messageType.name,
      'text_content': textContent,
      'reply_to_message_id': replyToMessageId,
      'sent_at': sentAt.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  Message copyWith({
    String? textContent,
    DateTime? editedAt,
    DateTime? deletedAt,
    DeliveryStatus? deliveryStatus,
    List<MessageAttachment>? attachments,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      messageType: messageType,
      textContent: textContent ?? this.textContent,
      replyToMessageId: replyToMessageId,
      sentAt: sentAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      senderFullName: senderFullName,
      senderAvatarUrl: senderAvatarUrl,
      attachments: attachments ?? this.attachments,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }
}
