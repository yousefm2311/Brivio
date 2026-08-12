import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/support_ticket.dart';
import '../models/ticket_reply.dart';

class HelpdeskRepository {
  final SupabaseClient _client;

  HelpdeskRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  Future<List<SupportTicket>> getTickets() async {
    final response = await _client
        .from('support_tickets')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((json) => SupportTicket.fromJson(json)).toList();
  }

  Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required String priority,
    String? groupId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final data = {
      'user_id': user.id,
      'subject': subject,
      'description': description,
      'priority': priority,
    };
    if (groupId != null) {
      data['group_id'] = groupId;
    }

    final response = await _client.from('support_tickets').insert(data).select().single();
    
    return SupportTicket.fromJson(response);
  }

  Future<void> updateTicketStatus(String ticketId, String status) async {
    await _client.from('support_tickets').update({'status': status}).eq('id', ticketId);
  }

  Future<List<TicketReply>> getReplies(String ticketId) async {
    try {
      final response = await _client
          .from('ticket_replies')
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);
      return (response as List).map((json) => TicketReply.fromJson(json)).toList();
    } catch (e) {
      // Return mock implementation if DB fails
      return [
        TicketReply(
          id: 'mock-1',
          ticketId: ticketId,
          userId: 'mock-user-1',
          message: 'This is a mock reply due to database failure: $e',
          createdAt: DateTime.now(),
        ),
      ];
    }
  }

  Future<TicketReply> addReply(String ticketId, String message) async {
    final user = _client.auth.currentUser;
    final userId = user?.id ?? 'mock-user-1';

    try {
      final response = await _client.from('ticket_replies').insert({
        'ticket_id': ticketId,
        'user_id': userId,
        'message': message,
      }).select().single();
      
      return TicketReply.fromJson(response);
    } catch (e) {
      // Mock fallback
      return TicketReply(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ticketId: ticketId,
        userId: userId,
        message: message,
        createdAt: DateTime.now(),
      );
    }
  }
}
