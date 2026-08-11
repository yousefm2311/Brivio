import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/support_ticket.dart';

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
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await _client.from('support_tickets').insert({
      'user_id': user.id,
      'subject': subject,
      'description': description,
      'priority': priority,
    }).select().single();
    
    return SupportTicket.fromJson(response);
  }

  Future<void> updateTicketStatus(String ticketId, String status) async {
    await _client.from('support_tickets').update({'status': status}).eq('id', ticketId);
  }
}
