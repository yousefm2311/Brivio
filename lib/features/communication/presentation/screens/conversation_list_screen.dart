import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../viewmodels/conversation_list_viewmodel.dart';
import 'chat_thread_screen.dart';

class ConversationListScreen extends StatefulWidget {
  final ConversationListViewModel viewModel;

  const ConversationListScreen({super.key, required this.viewModel});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('Conversations')),
            actions: [
              if (vm.totalUnreadCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Chip(
                    label: Text(
                      '${vm.totalUnreadCount} ${context.tr('Unread')}',
                    ),
                    backgroundColor: Colors.blue.shade100,
                  ),
                ),
            ],
          ),
          body: vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : vm.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${context.tr('Error')}: ${vm.errorMessage}',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: vm.loadConversations,
                        child: Text(context.tr('Retry')),
                      ),
                    ],
                  ),
                )
              : vm.conversations.isEmpty
              ? Center(
                  child: Text(
                    context.tr('No active conversations.'),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: vm.loadConversations,
                  child: ListView.separated(
                    itemCount: vm.conversations.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final conv = vm.conversations[index];
                      final isGroup = conv.conversationType.name == 'group';
                      final displayTitle =
                          conv.title ??
                          (conv.members.isNotEmpty
                              ? conv.members.first.userFullName ??
                                    context.tr('Direct Chat')
                              : context.tr('Conversation'));

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isGroup
                              ? Colors.purple.shade100
                              : Colors.blue.shade100,
                          child: Icon(
                            isGroup ? Icons.group : Icons.person,
                            color: isGroup ? Colors.purple : Colors.blue,
                          ),
                        ),
                        title: Text(
                          displayTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          conv.lastMessageText ?? context.tr('No messages yet'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${conv.lastMessageAt.hour}:${conv.lastMessageAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            if (conv.unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${conv.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatThreadScreen(
                                conversationId: conv.id,
                                title: displayTitle,
                              ),
                            ),
                          ).then((_) => vm.loadConversations());
                        },
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
