import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/message.dart';
import '../../domain/repositories/i_message_repository.dart';

class SupabaseMessageRepository implements IMessageRepository {
  final SupabaseClientWrapper _clientWrapper;
  final Map<String, RealtimeChannel> _activeChannels = {};

  SupabaseMessageRepository(this._clientWrapper);

  @override
  Future<List<Message>> getMessages({
    required String conversationId,
    int limit = 50,
    String? beforeMessageId,
  }) async {
    var query = _clientWrapper.client
        .from('messages')
        .select('''
          *,
          sender:profiles!sender_id (
            full_name,
            avatar_url
          ),
          message_attachments (*)
        ''')
        .eq('conversation_id', conversationId);

    if (beforeMessageId != null) {
      final refMsg = await _clientWrapper.client
          .from('messages')
          .select('sent_at')
          .eq('id', beforeMessageId)
          .maybeSingle();

      if (refMsg != null) {
        query = query.lt('sent_at', refMsg['sent_at']);
      }
    }

    final response = await query
        .order('sent_at', ascending: false)
        .limit(limit);

    final rawList = response as List<dynamic>;
    final messages = rawList
        .map((m) => Message.fromJson(m as Map<String, dynamic>))
        .toList();
    return messages.reversed.toList();
  }

  @override
  Future<Message> sendMessage({
    required String conversationId,
    required String text,
    String? replyToMessageId,
    MessageType messageType = MessageType.text,
  }) async {
    final res = await _clientWrapper.client.rpc(
      'send_message',
      params: {
        'p_conversation_id': conversationId,
        'p_text': text,
        'p_reply_to_message_id': replyToMessageId,
        'p_message_type': messageType.name,
      },
    );

    final msgId = res['message_id'] as String;

    final inserted = await _clientWrapper.client
        .from('messages')
        .select('''
          *,
          sender:profiles!sender_id (
            full_name,
            avatar_url
          ),
          message_attachments (*)
        ''')
        .eq('id', msgId)
        .single();

    return Message.fromJson(inserted);
  }

  @override
  Future<void> editMessage({
    required String messageId,
    required String newText,
  }) async {
    await _clientWrapper.client
        .from('messages')
        .update({
          'text_content': newText,
          'edited_at': DateTime.now().toIso8601String(),
        })
        .eq('id', messageId);
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    await _clientWrapper.client
        .from('messages')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', messageId);
  }

  @override
  Stream<Message> subscribeToRealtimeMessages(String conversationId) {
    final controller = StreamController<Message>.broadcast();

    final channelName = 'messages:$conversationId';
    if (_activeChannels.containsKey(channelName)) {
      _clientWrapper.client.removeChannel(_activeChannels[channelName]!);
    }

    final channel = _clientWrapper.client.channel(channelName);
    _activeChannels[channelName] = channel;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            final newRow = payload.newRecord;
            final msgId = newRow['id'] as String;
            try {
              final fullMsg = await _clientWrapper.client
                  .from('messages')
                  .select('''
                    *,
                    sender:profiles!sender_id (
                      full_name,
                      avatar_url
                    ),
                    message_attachments (*)
                  ''')
                  .eq('id', msgId)
                  .maybeSingle();

              if (fullMsg != null && !controller.isClosed) {
                controller.add(Message.fromJson(fullMsg));
              }
            } catch (_) {}
          },
        )
        .subscribe();

    controller.onCancel = () {
      unsubscribeRealtimeMessages(conversationId);
    };

    return controller.stream;
  }

  @override
  void unsubscribeRealtimeMessages(String conversationId) {
    final channelName = 'messages:$conversationId';
    if (_activeChannels.containsKey(channelName)) {
      _clientWrapper.client.removeChannel(_activeChannels[channelName]!);
      _activeChannels.remove(channelName);
    }
  }

  @override
  void clearCache() {
    for (final channel in _activeChannels.values) {
      _clientWrapper.client.removeChannel(channel);
    }
    _activeChannels.clear();
  }
}
