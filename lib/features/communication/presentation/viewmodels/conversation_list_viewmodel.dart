import 'package:flutter/foundation.dart';
import '../../domain/models/conversation.dart';
import '../../domain/repositories/i_conversation_repository.dart';

class ConversationListViewModel extends ChangeNotifier {
  final IConversationRepository _conversationRepository;

  List<Conversation> _conversations = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _totalUnreadCount = 0;

  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalUnreadCount => _totalUnreadCount;

  ConversationListViewModel(this._conversationRepository);

  Future<void> loadConversations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _conversations = await _conversationRepository.getConversations();
      _totalUnreadCount = await _conversationRepository
          .getUserUnreadConversationsTotal();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> startDirectConversation(String otherUserId) async {
    try {
      final convId = await _conversationRepository
          .getOrCreateDirectConversation(otherUserId);
      await loadConversations();
      return convId;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearState() {
    _conversations = [];
    _totalUnreadCount = 0;
    _errorMessage = null;
    _conversationRepository.clearCache();
    notifyListeners();
  }
}
