import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/message.dart';
import '../../domain/repositories/i_conversation_repository.dart';
import '../../domain/repositories/i_message_repository.dart';

class ChatThreadViewModel extends ChangeNotifier {
  final IMessageRepository messageRepository;
  final IConversationRepository conversationRepository;

  final String conversationId;
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  Message? _replyToTarget;
  StreamSubscription<Message>? _realtimeSubscription;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  Message? get replyToTarget => _replyToTarget;

  ChatThreadViewModel({
    required this.conversationId,
    required this.messageRepository,
    required this.conversationRepository,
  });

  Future<void> loadMessages() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _messages = await messageRepository.getMessages(
        conversationId: conversationId,
      );
      _subscribeRealtime();

      if (_messages.isNotEmpty) {
        await conversationRepository.markConversationRead(
          conversationId,
          _messages.last.id,
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeRealtime() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = messageRepository
        .subscribeToRealtimeMessages(conversationId)
        .listen((newMessage) {
          final existingIndex = _messages.indexWhere(
            (m) => m.id == newMessage.id,
          );
          if (existingIndex >= 0) {
            _messages[existingIndex] = newMessage;
          } else {
            _messages.add(newMessage);
          }
          conversationRepository.markConversationRead(
            conversationId,
            newMessage.id,
          );
          notifyListeners();
        });
  }

  void setReplyToTarget(Message? message) {
    _replyToTarget = message;
    notifyListeners();
  }

  Future<bool> sendMessage(String text) async {
    if (text.trim().isEmpty) return false;

    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final replyId = _replyToTarget?.id;
      final sent = await messageRepository.sendMessage(
        conversationId: conversationId,
        text: text.trim(),
        replyToMessageId: replyId,
      );

      final idx = _messages.indexWhere((m) => m.id == sent.id);
      if (idx < 0) {
        _messages.add(sent);
      }
      _replyToTarget = null;
      await conversationRepository.markConversationRead(
        conversationId,
        sent.id,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> editMessage(String messageId, String newText) async {
    try {
      await messageRepository.editMessage(
        messageId: messageId,
        newText: newText,
      );
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        _messages[idx] = _messages[idx].copyWith(
          textContent: newText,
          editedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await messageRepository.deleteMessage(messageId);
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        _messages[idx] = _messages[idx].copyWith(deletedAt: DateTime.now());
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    messageRepository.unsubscribeRealtimeMessages(conversationId);
    super.dispose();
  }
}
