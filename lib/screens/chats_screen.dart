import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/chats_cubit.dart';
import 'package:messaging/screens/settings_screen.dart';
import 'package:messaging/screens/single_chat_screen.dart';
import 'package:messaging/core/utils/date_formatter.dart';
import 'new_message_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatsCubit()..loadChats(),
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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: BlocBuilder<ChatsCubit, ChatsState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: context.read<ChatsCubit>().loadChats,
            child: CustomScrollView(
              slivers: [
                // 1. M3 Large App Bar
                SliverAppBar.medium(
                  title: const Text('Messages'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      ),
                    ),
                  ],
                ),
                
                // 2. Body Content
                if (state is ChatsLoading)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                else if (state is ChatsLoaded)
                    state.chats.isEmpty
                    ? SliverFillRemaining(child: _buildEmptyState(theme))
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildChatTile(state.chats[index], theme),
                          childCount: state.chats.length,
                        ),
                      )
                else
                  const SliverFillRemaining(child: Center(child: Text('Something went wrong'))),
              ],
            ),
          );
        },
      ),
      // 3. M3 Floating Action Button
      floatingActionButton: FloatingActionButton.extended(
        label: const Text('New'),


        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const NewMessageScreen()));
          if (mounted) context.read<ChatsCubit>().loadChats();
        },
        icon: const Icon(Icons.edit_outlined),
      ),
    );
  }

  Widget _buildChatTile(dynamic chat, ThemeData theme) {
    final bool hasUnread = chat.unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (context) => SingleChatScreen(threadId: chat.threadId, address: chat.address),
        )),
        onLongPress: () => _deleteChat(chat.threadId),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // Use tonal color for unread messages
            color: hasUnread ? theme.colorScheme.primaryContainer.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              // M3 Tonal Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: hasUnread ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                child: prefix(chat.address, hasUnread ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.address ,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.lastMessage ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: hasUnread ? theme.colorScheme.onSurface : theme.colorScheme.outline,
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
                      color: hasUnread ? theme.colorScheme.primary : theme.colorScheme.outline,
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
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chat_bubble_outline, size: 70, color: theme.colorScheme.primary.withOpacity(0.2)),
        const SizedBox(height: 16),
        Text('Quiet in here...', style: theme.textTheme.titleLarge),
        Text('Start a conversation to see it here.'),
      ],
    );
  }

  Widget prefix(String address, Color color) {
    if (address.startsWith(RegExp(r'[a-zA-Z]')) && address.isNotEmpty) {
      return Text(address[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold));
    }
    return Icon(Icons.person_outline, color: color);
  }

  Future<void> _deleteChat(String threadId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Delete Chat'),
        content: const Text('This will remove the conversation history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<ChatsCubit>().deleteChat(threadId);
    }
  }
}