import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/components/glass_card.dart';
import 'dart:ui';

class CommsTab extends StatefulWidget {
  const CommsTab({super.key});

  @override
  State<CommsTab> createState() => _CommsTabState();
}

class _CommsTabState extends State<CommsTab> {
  final CommsViewModel _viewModel = CommsViewModel();
  UserContact? _selectedContact;
  final TextEditingController _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    if (_selectedContact != null) {
      return _buildChatScreen(_selectedContact!, isDark, textPrimary, bgColor, surfaceColor, borderColor);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          context.tr('Messages'),
          style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _viewModel.contacts.length,
        itemBuilder: (context, index) {
          final contact = _viewModel.contacts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.teacherRole.withValues(alpha: 0.2),
                  child: Text(
                    contact.name.substring(0, 1),
                    style: TextStyle(color: AppColors.teacherRole, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  contact.name,
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  contact.role,
                  style: TextStyle(color: textPrimary.withValues(alpha: 0.6), fontSize: 12),
                ),
                trailing: const Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.teacherRole),
                onTap: () {
                  setState(() {
                    _selectedContact = contact;
                  });
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatScreen(UserContact contact, bool isDark, Color textPrimary, Color bgColor, Color surfaceColor, Color borderColor) {
    final messages = _viewModel.getMessagesForContact(contact.id);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () {
            setState(() {
              _selectedContact = null;
            });
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.teacherRole.withValues(alpha: 0.2),
              child: Text(
                contact.name.substring(0, 1),
                style: const TextStyle(color: AppColors.teacherRole, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name, style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                Text(contact.role, style: TextStyle(color: textPrimary.withValues(alpha: 0.6), fontSize: 12)),
              ],
            ),
          ],
        ),
        backgroundColor: surfaceColor.withValues(alpha: 0.8),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: textPrimary),
            onPressed: () => _showProfileDialog(contact, isDark, textPrimary),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg.isMe;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.teacherRole : surfaceColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: isMe ? null : Border.all(color: borderColor, width: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: isMe ? Colors.white : textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: borderColor, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      hintText: context.tr('Type a message...'),
                      hintStyle: TextStyle(color: textPrimary.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.teacherRole,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () {
                      if (_messageController.text.trim().isNotEmpty) {
                        setState(() {
                          _viewModel.sendMessage(contact.id, _messageController.text.trim());
                          _messageController.clear();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(UserContact contact, bool isDark, Color textPrimary) {
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.teacherRole.withValues(alpha: 0.2),
                      child: Text(
                        contact.name.substring(0, 1),
                        style: const TextStyle(color: AppColors.teacherRole, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      contact.name,
                      style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.teacherRole.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        contact.role,
                        style: const TextStyle(color: AppColors.teacherRole, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildProfileRow(Icons.email_outlined, '${contact.name.toLowerCase().replaceAll(' ', '.')}@example.com', textPrimary),
                    const SizedBox(height: 12),
                    _buildProfileRow(Icons.phone_outlined, '+1 234 567 8900', textPrimary),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teacherRole,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.tr('Close')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(IconData icon, String text, Color textPrimary) {
    return Row(
      children: [
        Icon(icon, size: 20, color: textPrimary.withValues(alpha: 0.5)),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: textPrimary, fontSize: 14)),
      ],
    );
  }
}

class UserContact {
  final String id;
  final String name;
  final String role;

  UserContact({required this.id, required this.name, required this.role});
}

class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isMe, required this.timestamp});
}

class CommsViewModel {
  final List<UserContact> contacts = [
    UserContact(id: '1', name: 'John Doe', role: 'Student'),
    UserContact(id: '2', name: 'Jane Smith', role: 'Parent'),
    UserContact(id: '3', name: 'Alice Johnson', role: 'Student'),
  ];

  final Map<String, List<ChatMessage>> _messages = {
    '1': [
      ChatMessage(text: 'Hello, Mr. Teacher! I have a question about the assignment.', isMe: false, timestamp: DateTime.now().subtract(const Duration(minutes: 10))),
      ChatMessage(text: 'Sure John, what do you need help with?', isMe: true, timestamp: DateTime.now().subtract(const Duration(minutes: 5))),
    ],
    '2': [
      ChatMessage(text: 'Good morning, how is Jane doing in class?', isMe: false, timestamp: DateTime.now().subtract(const Duration(days: 1))),
    ],
  };

  List<ChatMessage> getMessagesForContact(String contactId) {
    return _messages[contactId] ?? [];
  }

  void sendMessage(String contactId, String text) {
    if (!_messages.containsKey(contactId)) {
      _messages[contactId] = [];
    }
    _messages[contactId]!.add(ChatMessage(
      text: text,
      isMe: true,
      timestamp: DateTime.now(),
    ));
  }
}
