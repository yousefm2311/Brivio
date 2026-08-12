class TicketReply {
  final String id;
  final String ticketId;
  final String userId;
  final String message;
  final DateTime createdAt;

  TicketReply({
    required this.id,
    required this.ticketId,
    required this.userId,
    required this.message,
    required this.createdAt,
  });

  factory TicketReply.fromJson(Map<String, dynamic> json) {
    return TicketReply(
      id: json['id'] as String,
      ticketId: json['ticket_id'] as String,
      userId: json['user_id'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'user_id': userId,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
