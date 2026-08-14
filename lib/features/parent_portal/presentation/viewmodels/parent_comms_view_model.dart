import 'package:flutter/foundation.dart';

class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String author;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.author,
  });
}

class Message {
  final String id;
  final String sender;
  final String content;
  final DateTime timestamp;
  final bool isFromMe;

  Message({
    required this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
    required this.isFromMe,
  });
}

class ParentCommsViewModel extends ChangeNotifier {
  List<Announcement> _announcements = [];
  List<Announcement> get announcements => _announcements;

  List<Message> _messages = [];
  List<Message> get messages => _messages;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  ParentCommsViewModel() {
    _loadMockData();
  }

  Future<void> _loadMockData() async {
    _isLoading = true;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    _announcements = [
      Announcement(
        id: '1',
        title: 'Science Fair Next Week!',
        content:
            'Please remind your children to bring their science fair projects by Monday. We are excited to see their creativity!',
        date: DateTime.now().subtract(const Duration(days: 1)),
        author: 'Principal Smith',
      ),
      Announcement(
        id: '2',
        title: 'School Closed on Friday',
        content:
            'School will be closed this Friday for a teacher training day. Have a great long weekend.',
        date: DateTime.now().subtract(const Duration(days: 3)),
        author: 'Administration',
      ),
    ];

    _messages = [
      Message(
        id: '1',
        sender: 'Mrs. Johnson',
        content:
            'Hi! Just wanted to let you know Timmy did great on his math test today.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isFromMe: false,
      ),
      Message(
        id: '2',
        sender: 'Me',
        content: 'That is wonderful news, thank you for letting me know!',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        isFromMe: true,
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    _messages.add(
      Message(
        id: DateTime.now().toString(),
        sender: 'Me',
        content: text.trim(),
        timestamp: DateTime.now(),
        isFromMe: true,
      ),
    );
    notifyListeners();
  }
}
