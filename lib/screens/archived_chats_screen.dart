import 'package:flutter/material.dart';
import 'package:messaging/core/utils/date_formatter.dart';
import 'package:messaging/models/app_chat.dart';
import 'package:messaging/screens/single_chat_screen.dart';
import 'package:messaging/screens/widgets/contact_name_text.dart';
import 'package:messaging/services/contact_service.dart';
import 'package:messaging/services/redact_service.dart';
import 'package:messaging/services/sms_service.dart';

class ArchivedChatsScreen extends StatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  State<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<ArchivedChatsScreen> {
  bool? changed;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
    if (didPop) return;

    Navigator.pop(context, changed);
  },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Archived Conversations"),
        ),
        body: FutureBuilder<List<AppChat>>(
          // Replace with your actual service call
          future: SmsService().getArchivedChats(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
      
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text("No archived messages found."),
              );
            }
      
            final archived = snapshot.data!;
            return ListView.builder(
              itemCount: archived.length,
              itemBuilder: (context, index) {
                final chat = archived[index];
                final bool hasUnread = chat.unreadCount > 0;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SingleChatScreen(
                                threadId: chat.threadId, address: chat.address),
                          ));
                    },
                    onLongPress: () => _unArchiveChat(context, chat.threadId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        // If selected, use a strong primary container tint
                        color: (hasUnread
                            ? theme.colorScheme.primaryContainer.withAlpha(100)
                            : Colors.transparent),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          // M3 Tonal Avatar
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: (hasUnread
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surfaceContainerHighest),
                                child: chat.prefix(hasUnread
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurfaceVariant),
                              ),
                              // Show a small pin badge if the chat is pinned
                              if (chat.isPinned)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: theme.colorScheme.outlineVariant,
                                          width: 1),
                                    ),
                                    child: Icon(
                                      Icons.push_pin,
                                      size: 12,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ContactNameText(
                                    unread: hasUnread,
                                    rawAddress: chat.address,
                                    contactStream:
                                        ContactService().contactStream),
                                const SizedBox(height: 4),
                                Text(
                                  RedactService.redactAfterBalance(
                                      chat.lastMessage ?? '', chat.address),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: (hasUnread
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.outline),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatDate(chat.lastMessageDate),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: hasUnread
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (hasUnread)
                                Badge(
                                  label: Text(chat.unreadCount.toString()),
                                  backgroundColor: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

    Future<void> _unArchiveChat(BuildContext context, String threadId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.unarchive_outlined),
        title: const Text('Unarchive chat?'),
        content: const Text(
            'This will remove this conversation from archive'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unarchive'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      SmsService().markThreadsAsArchived([threadId], false);
      setState(() {
        changed = true;
      });
    }
  }
}
