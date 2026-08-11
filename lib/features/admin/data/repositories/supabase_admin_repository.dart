import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/admin_models.dart';
import '../../domain/repositories/i_admin_repository.dart';

class SupabaseAdminRepository implements IAdminRepository {
  final SupabaseClientWrapper _supabaseClientWrapper;

  SupabaseAdminRepository(this._supabaseClientWrapper);

  SupabaseClient get _client => _supabaseClientWrapper.client;

  @override
  Future<AdminSetting?> getSetting(String key) async {
    final response = await _client.rpc(
      'get_admin_setting',
      params: {'setting_key': key},
    );
    if (response == null) return null;
    return AdminSetting(
      key: key,
      value: response,
      updatedAt: DateTime.now(), // Real time comes from table normally
    );
  }

  @override
  Future<void> updateSetting(String key, dynamic value) async {
    await _client.rpc(
      'set_admin_setting',
      params: {'setting_key': key, 'setting_value': value},
    );
  }

  @override
  Future<String> createRole(String name, List<String> permissions) async {
    final response = await _client.rpc(
      'create_admin_role',
      params: {'role_name': name, 'role_permissions': permissions},
    );
    return response as String;
  }

  @override
  Future<void> assignRole(String userId, String roleId) async {
    await _client.rpc(
      'assign_admin_role',
      params: {'target_user_id': userId, 'target_role_id': roleId},
    );
  }

  @override
  Future<List<AdminRole>> getRoles() async {
    final response = await _client.from('admin_roles').select();
    return (response as List).map((json) => AdminRole.fromJson(json)).toList();
  }

  @override
  Future<AdminAnalytics> getAnalytics(DateTime startDate, DateTime endDate) async {
    final response = await _client.rpc(
      'get_admin_analytics',
      params: {
        'period_start': startDate.toIso8601String(),
        'period_end': endDate.toIso8601String(),
      },
    );
    return AdminAnalytics.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<HelpdeskTicket>> getTickets() async {
    final response = await _client
        .from('helpdesk_tickets')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((json) => HelpdeskTicket.fromJson(json)).toList();
  }

  @override
  Future<HelpdeskTicket> createTicket(String subject, String description, String priority) async {
    final user = _supabaseClientWrapper.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await _client.from('helpdesk_tickets').insert({
      'user_id': user.id,
      'subject': subject,
      'description': description,
      'priority': priority,
    }).select().single();
    
    return HelpdeskTicket.fromJson(response);
  }

  @override
  Future<void> updateTicketStatus(String ticketId, String status) async {
    await _client.from('helpdesk_tickets').update({'status': status}).eq('id', ticketId);
  }

  @override
  Future<void> moderateUserStatus(String userType, String userId, String status) async {
    await _client.rpc(
      'moderate_user_status',
      params: {
        'p_user_type': userType,
        'p_user_id': userId,
        'p_status': status,
      },
    );
  }
}
