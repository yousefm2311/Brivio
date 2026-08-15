import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/support_ticket.dart';
import '../models/ticket_reply.dart';

class HelpdeskGroupOption {
  final String id;
  final String name;

  const HelpdeskGroupOption({required this.id, required this.name});

  factory HelpdeskGroupOption.fromGroup(Map<String, dynamic> group) {
    final name = [
      group['name']?.toString(),
      group['code']?.toString(),
    ].where((v) => v != null && v.trim().isNotEmpty).join(' - ');
    return HelpdeskGroupOption(
      id: group['id'].toString(),
      name: name.isEmpty ? 'Group' : name,
    );
  }
}

class HelpdeskRepository {
  final SupabaseClient _client;

  HelpdeskRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<List<SupportTicket>> getTickets() async {
    final response = await _client
        .from('support_tickets')
        .select()
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => SupportTicket.fromJson(json))
        .toList();
  }

  Future<List<HelpdeskGroupOption>> getAvailableGroups() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final groups = <String, HelpdeskGroupOption>{};

    Future<void> addGroupRows(List<dynamic> rows) async {
      for (final row in rows) {
        final map = Map<String, dynamic>.from(row as Map);
        final groupRaw = map['groups'] ?? map['group'];
        if (groupRaw is Map) {
          final option = HelpdeskGroupOption.fromGroup(
            Map<String, dynamic>.from(groupRaw),
          );
          groups[option.id] = option;
        }
      }
    }

    final student = await _client
        .from('students')
        .select('id')
        .eq('profile_id', user.id)
        .maybeSingle();
    if (student != null) {
      final rows = await _client
          .from('enrollments')
          .select('groups(id, name, code)')
          .eq('student_id', student['id'])
          .eq('status', 'active');
      await addGroupRows(rows as List<dynamic>);
    }

    final parent = await _client
        .from('parents')
        .select('id')
        .eq('profile_id', user.id)
        .maybeSingle();
    if (parent != null) {
      final links = await _client
          .from('parent_students')
          .select('student_id')
          .eq('parent_id', parent['id']);
      final studentIds = (links as List<dynamic>)
          .map((row) => (row as Map)['student_id']?.toString())
          .whereType<String>()
          .toList();
      if (studentIds.isNotEmpty) {
        final rows = await _client
            .from('enrollments')
            .select('groups(id, name, code)')
            .inFilter('student_id', studentIds)
            .eq('status', 'active');
        await addGroupRows(rows as List<dynamic>);
      }
    }

    final teacher = await _client
        .from('teachers')
        .select('id')
        .eq('profile_id', user.id)
        .maybeSingle();
    if (teacher != null) {
      final rows = await _client
          .from('group_teachers')
          .select('groups(id, name, code)')
          .eq('teacher_id', teacher['id']);
      await addGroupRows(rows as List<dynamic>);
    }

    return groups.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required String priority,
    String? groupId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await _client.rpc(
      'create_support_ticket',
      params: {
        'p_subject': subject,
        'p_description': description,
        'p_priority': priority,
        'p_group_id': groupId,
      },
    );

    return SupportTicket.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> updateTicketStatus(String ticketId, String status) async {
    await _client.rpc(
      'update_support_ticket_status',
      params: {'p_ticket_id': ticketId, 'p_status': status},
    );
  }

  Future<List<TicketReply>> getReplies(String ticketId) async {
    final response = await _client
        .from('ticket_replies')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);
    return (response as List)
        .map((json) => TicketReply.fromJson(json))
        .toList();
  }

  Future<TicketReply> addReply(String ticketId, String message) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await _client.rpc(
      'add_ticket_reply',
      params: {'p_ticket_id': ticketId, 'p_message': message},
    );

    return TicketReply.fromJson(Map<String, dynamic>.from(response as Map));
  }
}
