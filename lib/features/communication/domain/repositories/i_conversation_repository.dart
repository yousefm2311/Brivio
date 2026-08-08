import '../models/conversation.dart';

abstract class IConversationRepository {
  Future<List<Conversation>> getConversations();
  Future<String> getOrCreateDirectConversation(String otherUserId);
  Future<Conversation?> getConversationById(String conversationId);
  Future<void> markConversationRead(String conversationId, String messageId);
  Future<int> getConversationUnreadCount(String conversationId);
  Future<int> getUserUnreadConversationsTotal();
  Stream<void> subscribeToConversationListUpdates();
  void clearCache();
}
