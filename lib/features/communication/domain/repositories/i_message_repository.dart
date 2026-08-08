import '../models/message.dart';

abstract class IMessageRepository {
  Future<List<Message>> getMessages({
    required String conversationId,
    int limit = 50,
    String? beforeMessageId,
  });

  Future<Message> sendMessage({
    required String conversationId,
    required String text,
    String? replyToMessageId,
    MessageType messageType = MessageType.text,
  });

  Future<void> editMessage({
    required String messageId,
    required String newText,
  });

  Future<void> deleteMessage(String messageId);

  Stream<Message> subscribeToRealtimeMessages(String conversationId);
  void unsubscribeRealtimeMessages(String conversationId);
  void clearCache();
}
