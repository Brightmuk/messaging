import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/cubit/chats_cubit.dart';
import 'package:messaging/screens/settings_screen.dart';
import 'package:messaging/screens/single_chat_screen.dart';
import 'package:messaging/core/utils/date_formatter.dart';
import 'package:messaging/screens/widgets/chats_loading_widget.dart';
import 'package:messaging/screens/widgets/contact_name_text.dart';
import 'package:messaging/services/ads/native_ads_service.dart';
import 'package:messaging/services/contact_service.dart';
import 'package:messaging/services/notification_service.dart';
import 'package:messaging/services/redact_service.dart';
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

class ChatsView extends StatefulWidget with WidgetsBindingObserver{
  const ChatsView({super.key});

  @override
  State<ChatsView> createState() => _ChatsViewState();
}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
     _clearNotifications();
    }
  }
  void _clearNotifications() {
    NotificationService().removeNotifications();
  }

class _ChatsViewState extends State<ChatsView> {
  NativeAd? _myLoadedNativeAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
   if (!_isAdLoaded && !_isAdLoading) {
      _loadNativeAd();
    }
  }

void _loadNativeAd() async {
    _isAdLoading = true;

   await NativeAdService.loadNativeAd(
      context, 
      onAdLoaded: (loadedAd) {
        if (!mounted) {
          loadedAd.dispose();
          return;
        }
        setState(() {
          _isAdLoaded = true;
          _isAdLoading = false;
          _myLoadedNativeAd = loadedAd;
        });
      },
    );
  }
  @override
  void dispose() {
    _myLoadedNativeAd?.dispose();
    super.dispose();
  }
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
                
                if (state is ChatsLoading)
                 const SliverFillRemaining(child: ChatsLoadingWidget())
              else if (state is ChatsLoaded)
                state.chats.isEmpty
                    ? const SliverFillRemaining(child: ChatsLoadingWidget(isEmptyState: true))
                    : 
                    
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // 1. Show the ad at the specific position
                    if (index == 6) {
                      return _buildNativeAdTile();
                    }

                    // 2. Calculate the chat index
                    // If we are past the ad, subtract 1 to "stay on track" with the list
                    final int chatIndex = index > 6 ? index - 1 : index;

                    // 3. Safety check for list bounds
                    if (chatIndex >= state.chats.length) return null;

                    return _buildChatTile(state.chats[chatIndex], theme);
                  },
                  // 4. Important: itemCount is chats + 1 (for the single ad)
                  childCount: state.chats.length + 1,
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
                   
                    ContactNameText(unread: hasUnread, rawAddress: chat.address, contactStream: ContactService().contactStream),
                    const SizedBox(height: 4),
                    Text(
                      RedactService.redactBalances(chat.lastMessage ?? '', chat.address),
                      
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
  Widget _buildNativeAdTile() {

  return FutureBuilder<bool>(
    future: UserDefaults.getAdsRemoved(),
    builder: (context, asyncSnapshot) {
      if ((asyncSnapshot.hasData && asyncSnapshot.data == true) || _myLoadedNativeAd == null || !_isAdLoaded) {
        return const SizedBox.shrink();
      }
      
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        height: 80, 
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AdWidget(ad: _myLoadedNativeAd!), 
        ),
      );
    }
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
