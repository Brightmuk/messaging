import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:messaging/cubit/chats_cubit.dart';
import 'package:messaging/screens/single_chat_screen.dart';
import '../services/sms_service.dart';
import 'new_message_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatsCubit(SmsService()),
      child: const ChatsView(),
    );
  }
}

class ChatsView extends StatefulWidget {
  const ChatsView({super.key});

  @override
  State<ChatsView> createState() => _ChatsViewState();
}

class _ChatsViewState extends State<ChatsView> {
  final SmsService _smsService = SmsService();


  void _showDefaultSmsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set as Default SMS App'),
        content: const Text(
          'Would you like to set this as your default SMS app? '
          'This is required to receive messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _smsService.requestDefaultSmsApp();
            },
            child: const Text('Set as Default'),
          ),
        ],
      ),
    );
  }

  String _formatDate(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  Future<void> _deleteChat(String threadId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure you want to delete this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _smsService.deleteThread(threadId);
      context.read<ChatsCubit>().loadChats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed:(){},
            tooltip: 'Settings',
          ),
        ],
      ),
      body: BlocBuilder<ChatsCubit, ChatsState>(builder: (context, state) {
        if (state is ChatsLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is ChatsLoaded) {
          final chats = state.chats;
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.message_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a chat',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            );
          } else {
            return RefreshIndicator(
              onRefresh: context.read<ChatsCubit>().loadChats,
              child: ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        chat.address.isNotEmpty
                            ? chat.address[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(
                      chat.address,
                      style: TextStyle(
                        fontWeight: chat.unreadCount > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      chat.lastMessage ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: chat.unreadCount > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatDate(chat.lastMessageDate),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (chat.unreadCount > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              chat.unreadCount.toString(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () async {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            threadId: chat.threadId,
                            address: chat.address,
                          ),
                        )
                      );
                      
                    },
                    onLongPress: () => _deleteChat(chat.threadId),
                  );
                },
              ),
            );
          }
        }
        return const Center(child: Text('Something went wrong'));
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NewMessageScreen(),
            ),
          );
          context.read<ChatsCubit>().loadChats();
        },
        icon: const Icon(Icons.edit_outlined),
        label: const Text('New'),
      ),
    );
  }
}
