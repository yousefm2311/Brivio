import 'dart:async';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/conversation.dart';
import '../../domain/repositories/i_conversation_repository.dart';

class SupabaseConversationRepository implements IConversationRepository {
  final SupabaseClientWrapper _clientWrapper;

  SupabaseConversationRepository(this._clientWrapper);

  @override
  Future<List<Conversation>> getConversations() async {
    final response = await _clientWrapper.client
        .from('conversations')
        .select('''
          *,
          conversation_members (
            id,
            conversation_id,
            user_id,
            member_role,
            joined_at,
            left_at,
            last_read_message_id,
            last_read_at,
            muted_until,
            profiles (
              full_name,
              email,
              avatar_url
            )
          )
        ''')
        .order('last_message_at', ascending: false);

    final conversations = <Conversation>[];
    for (final row in response) {
      final convId = row['id'] as String;
      final unreadCount = await getConversationUnreadCount(convId);
      conversations.add(Conversation.fromJson(row, unreadCount: unreadCount));
    }
    return conversations;
  }

  @override
  Future<String> getOrCreateDirectConversation(String otherUserId) async {
    final res = await _clientWrapper.client.rpc(
      'get_or_create_direct_conversation',
      params: {'p_other_user_id': otherUserId},
    );
    return res['conversation_id'] as String;
  }

  @override
  Future<Conversation?> getConversationById(String conversationId) async {
    final response = await _clientWrapper.client
        .from('conversations')
        .select('''
          *,
          conversation_members (
            id,
            conversation_id,
            user_id,
            member_role,
            joined_at,
            left_at,
            last_read_message_id,
            last_read_at,
            muted_until,
            profiles (
              full_name,
              email,
              avatar_url
            )
          )
        ''')
        .eq('id', conversationId)
        .maybeSingle();

    if (response == null) return null;
    final unreadCount = await getConversationUnreadCount(conversationId);
    return Conversation.fromJson(response, unreadCount: unreadCount);
  }

  @override
  Future<void> markConversationRead(
    String conversationId,
    String messageId,
  ) async {
    await _clientWrapper.client.rpc(
      'mark_conversation_read',
      params: {'p_conversation_id': conversationId, 'p_message_id': messageId},
    );
  }

  @override
  Future<int> getConversationUnreadCount(String conversationId) async {
    final res = await _clientWrapper.client.rpc(
      'get_conversation_unread_count',
      params: {'p_conversation_id': conversationId},
    );
    return (res as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> getUserUnreadConversationsTotal() async {
    final res = await _clientWrapper.client.rpc(
      'get_user_unread_conversations_total',
    );
    return (res as num?)?.toInt() ?? 0;
  }

  @override
  Stream<void> subscribeToConversationListUpdates() {
    return _clientWrapper.client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .map((_) {});
  }

  @override
  void clearCache() {
    // Purge cached references on sign-out
  }
}
