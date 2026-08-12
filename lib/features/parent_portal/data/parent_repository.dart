import 'package:supabase_flutter/supabase_flutter.dart';

class ParentRepository {
  final SupabaseClient _supabaseClient;

  ParentRepository({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client;

  Future<void> linkChildWithId(String studentId) async {
    final parentId = _supabaseClient.auth.currentUser?.id;
    if (parentId == null) throw Exception('User not logged in');

    await _supabaseClient.from('parent_student_links').insert({
      'parent_id': parentId,
      'student_id': studentId,
      'status': 'active',
    });
  }

  Future<List<Map<String, dynamic>>> getLinkedChildren() async {
    final parentId = _supabaseClient.auth.currentUser?.id;
    if (parentId == null) throw Exception('User not logged in');

    final response = await _supabaseClient
        .from('parent_student_links')
        .select('*, student:student_id(*)')
        .eq('parent_id', parentId)
        .eq('status', 'active');
    
    return List<Map<String, dynamic>>.from(response);
  }
}
