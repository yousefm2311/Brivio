import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/i_conversation_repository.dart';
import '../../domain/repositories/i_message_repository.dart';
import '../viewmodels/chat_thread_viewmodel.dart';

class ChatThreadScreen extends StatefulWidget {
  final String conversationId;
  final String title;

  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    required this.title,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  late final ChatThreadViewModel _viewModel;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = ChatThreadViewModel(
      conversationId: widget.conversationId,
      messageRepository: getIt<IMessageRepository>(),
      conversationRepository: getIt<IConversationRepository>(),
    );
    _viewModel.loadMessages();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _handleSend() async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    final success = await _viewModel.sendMessage(text);
    if (success) {
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: Column(
            children: [
              if (_viewModel.errorMessage != null)
                Container(
                  color: Colors.red.shade100,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _viewModel.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _viewModel.loadMessages(),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: _viewModel.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _viewModel.messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet. Send a message to start conversing!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _viewModel.messages.length,
                        itemBuilder: (context, index) {
                          final msg = _viewModel.messages[index];
                          final isDeleted = msg.isDeleted;

                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDeleted
                                    ? Colors.grey.shade200
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (msg.senderFullName != null)
                                    Text(
                                      msg.senderFullName!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isDeleted
                                        ? 'This message was deleted'
                                        : (msg.textContent ?? ''),
                                    style: TextStyle(
                                      fontStyle: isDeleted
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                      color: isDeleted
                                          ? Colors.grey
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${msg.sentAt.hour}:${msg.sentAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              if (_viewModel.replyToTarget != null)
                Container(
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.reply, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Replying to: ${_viewModel.replyToTarget!.textContent}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => _viewModel.setReplyToTarget(null),
                      ),
                    ],
                  ),
                ),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Type your message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                    IconButton(
                      icon: _viewModel.isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: Colors.blue),
                      onPressed: _viewModel.isSending ? null : _handleSend,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
