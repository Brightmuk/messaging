import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/core/feedback_ui.dart';
import 'package:messaging/cubit/chats_cubit.dart';
import 'package:messaging/cubit/payment_cubit.dart';
import 'package:messaging/models/app_chat.dart';
import 'package:messaging/screens/global_search_page.dart';
import 'package:messaging/screens/settings_screen.dart';
import 'package:messaging/screens/single_chat_screen.dart';
import 'package:messaging/core/utils/date_formatter.dart';
import 'package:messaging/screens/widgets/ad_free_tile.dart';
import 'package:messaging/screens/widgets/chats_loading_widget.dart';
import 'package:messaging/screens/widgets/chats_native_ad.dart';
import 'package:messaging/screens/widgets/contact_name_text.dart';
import 'package:messaging/screens/widgets/rating_dialog.dart';
import 'package:messaging/services/contact_service.dart';
import 'package:messaging/services/notification_service.dart';
import 'package:messaging/services/rating_limiter.dart';
import 'package:messaging/services/redact_service.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:provider/provider.dart';
import 'select_contact_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final feedbackui = FeedbackUi(context);
    return BlocProvider(
      create: (context) => ChatsCubit(),
      child: BlocListener<PaymentCubit, PaymentState>(
        listener: (context, state) {
          if (state is PaymentSuccess) {
            feedbackui.showSuccess("No Ads forever!");
          }
          if (state is PaymentFailed) {
            feedbackui.showError(state.message);
          }
        },
        child: const ChatsView(),
      ),
    );
  }
}

class ChatsView extends StatefulWidget {
  const ChatsView({super.key});

  @override
  State<ChatsView> createState() => _ChatsViewState();
}

class _ChatsViewState extends State<ChatsView> with WidgetsBindingObserver {
  Set<String> _selectedThreadIds = {};
  bool get _isSelectionMode => _selectedThreadIds.isNotEmpty;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkDialogs();
    });
  }

  Future<void> _checkDialogs() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // PRIORITY 1: Rating Dialog
    if (await RateLimiter.shouldShowRateDialog()) {
      showRateUsDialog(context);
      return;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _clearNotifications();
      context.read<ChatsCubit>().loadChats(isInitialLoad: false);

    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      context.read<ChatsCubit>().loadChats(isInitialLoad: false);
    }
  }

  void _clearNotifications() {
    NotificationService().removeNotifications();
  }

  void _toggleSelection(String threadId) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_selectedThreadIds.contains(threadId)) {
        _selectedThreadIds.remove(threadId);
      } else {
        _selectedThreadIds.add(threadId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedThreadIds.clear();
    });
  }

  void _selectAll(List<dynamic> chats) {
    setState(() {
      _selectedThreadIds = chats.map((chat) => chat.threadId as String).toSet();
    });
  }

  bool _isAllSelected(List<dynamic> chats) {
    return _selectedThreadIds.length == chats.length && chats.isNotEmpty;
  }

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  bool areAllSelectedPinned(List<AppChat> chats) {
    final selectedChats =
        chats.where((chat) => _selectedThreadIds.contains(chat.threadId));
    return selectedChats.every((chat) => chat.isPinned);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool isNoAds = Provider.of<PaymentCubit>(context).isNoAds;

    return Scaffold(
      body: BlocBuilder<ChatsCubit, ChatsState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: context.read<ChatsCubit>().loadChats,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
               if (state is ChatsLoading || state is ChatsInitial || state is ChatsError || state is PermissionRevoked)
                  const SliverAppBar.medium() 
                else if (state is ChatsLoaded)
                  SliverAppBar.medium(
                    title: Text(_isSelectionMode
                        ? '${_selectedThreadIds.length} selected'
                        : 'Messages'),
                    leading: _isSelectionMode
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _clearSelection,
                          )
                        : null,
                    actions: _isSelectionMode
                        ? [
                            IconButton(
                              icon: Icon(areAllSelectedPinned(state.chats)
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined),
                              onPressed: () async {
                                final count = _selectedThreadIds.length;
                                if (areAllSelectedPinned(state.chats)) {
                                  await context
                                      .read<ChatsCubit>()
                                      .pinChats(_selectedThreadIds, false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('$count chat(s) unpinned')),
                                    );
                                  }
                                } else {
                                  await context
                                      .read<ChatsCubit>()
                                      .pinChats(_selectedThreadIds, true);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('$count chat(s) pinned')),
                                    );
                                  }
                                }
                                _clearSelection();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.archive_outlined),
                              onPressed: () async {
                                final count = _selectedThreadIds.length;
                                await context
                                    .read<ChatsCubit>()
                                    .archiveChats(_selectedThreadIds);
                                _clearSelection();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('$count chats archived')),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(_isAllSelected(state.chats)
                                  ? Icons.playlist_remove_outlined
                                  : Icons.playlist_add_check_outlined),
                              onPressed: () {
                                if (_isAllSelected(state.chats)) {
                                  _clearSelection();
                                } else {
                                  _selectAll(state.chats);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteSelectedChats(),
                            ),
                          ]
                        : [
                            IconButton(
                                icon: const Icon(Icons.search_outlined),
                                onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const GlobalSearchPage()),
                                    )),
                            IconButton(
                              icon: const Icon(Icons.settings_outlined),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const SettingsScreen()),
                              ),
                            ),
                          ],
                  ),
                  if( state is PermissionRevoked)
                    SliverFillRemaining(child: _buildDefaultRolePrompt(context))
                else if (state is ChatsLoading || state is ChatsInitial)
                  const SliverFillRemaining(child: ChatsLoadingWidget())
                else if (state is ChatsLoaded)
                  state.chats.isEmpty
                      ? const SliverFillRemaining(
                          child: ChatsLoadingWidget(isEmptyState: true))
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (isNoAds) {
                                return _buildChatTile(state.chats[index]);
                              }
                              // 1. Position for Native Banner Ad (Index 6)
                              if (index == 6) {
                                return const ChatsNativeAd();
                              }

                              // 2. Position for "Go Ad-Free" Internal Ad (Index 15)
                              // We check state.chats.length to ensure we don't show an ad
                              // if the list is too short.
                              if (index == 9 && state.chats.length >= 9) {
                                return const Padding(
                                  padding: EdgeInsets.all(10.0),
                                  child: AdFreeTile(),
                                );
                              }

                              // 3. Calculate the actual data index
                              int chatIndex = index;
                              if (index > 9) {
                                chatIndex = index -
                                    2; // Two ads are "pushing" the list down
                              } else if (index > 6) {
                                chatIndex = index -
                                    1; // Only the first ad is pushing it
                              }

                              // 4. Safety check
                              if (chatIndex >= state.chats.length ||
                                  chatIndex < 0) {
                                return null;
                              }

                              return _buildChatTile(state.chats[chatIndex]);
                            },
                            // 5. Total count is chats + 2 (one for each ad)
                            childCount: isNoAds
                                ? state.chats.length
                                : state.chats.length +
                                    (state.chats.length >= 8 ? 2 : 1),
                          ),
                        )
                else
                  SliverFillRemaining(
                      child: Center(
                          child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 30,
                        color: theme.colorScheme.tertiaryContainer,
                      ),
                     
                    ],
                  ))),
              ],
            ),
          );
        },
      ),
      // 3. M3 Floating Action Button
      floatingActionButton:  FloatingActionButton.extended(
        label: const Text('New'),
        onPressed: () async {
         final isdefault = await SmsService.isDefaultSmsApp();
         if(!isdefault) return;
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const SelectContactScreen()));
        },
        icon: const Icon(Icons.edit_outlined),
      ),
    );
  }
    Widget _buildDefaultRolePrompt(BuildContext context) {
      final theme = Theme.of(context);
  return Container(
    padding: const EdgeInsets.all(32),
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_person_outlined, 
          size: 80, 
          color: theme.colorScheme.primary.withOpacity(0.8)
        ),
        const SizedBox(height: 32),
        Text("Enable Privacy Features", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        const Text(
          "To display your messages securely and keep your M-Pesa balances hidden, M-Ficha needs certain permissions ",
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 50),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.read<ChatsCubit>().requestDefaultRole(),
            child: const Text("Grant Permissions"),
          ),
        ),
        const SizedBox(height: 100),
      ],
    ),
  );
}

  Widget _buildChatTile(AppChat chat) {
    final theme = Theme.of(context);
    final bool isSelected = _selectedThreadIds.contains(chat.threadId);
    final bool hasUnread = chat.unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(chat.threadId);
          } else {
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SingleChatScreen(
                      threadId: chat.threadId, address: chat.address),
                ));
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            _toggleSelection(chat.threadId);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : (hasUnread
                      ? theme.colorScheme.primaryContainer.withAlpha(100)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(20),
              border: Border(
                  bottom: BorderSide(
                      color: theme.colorScheme.surfaceContainer, width: 0.8))),
          child: Row(
            children: [
              // M3 Tonal Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isSelected
                        ? theme.colorScheme.primary
                        : (hasUnread
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest),
                    child: isSelected
                        ? Icon(Icons.check, color: theme.colorScheme.onPrimary)
                        : chat.prefix(hasUnread
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant),
                  ),
                  // Show a small pin badge if the chat is pinned
                  if (chat.isPinned && !isSelected)
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
                        contactStream: ContactService().contactStream),
                    const SizedBox(height: 4),
                    Text(
                      RedactService.redactAfterBalance(
                          chat.lastMessage ?? '', chat.address),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : (hasUnread
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
  }

  Future<void> _deleteSelectedChats() async {
    final count = _selectedThreadIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: Text('Delete $count ${count == 1 ? 'chat' : 'chats'}?'),
        content: const Text(
            'This will remove these conversations from your device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Call the Cubit bulk delete instead of a local loop
      await context.read<ChatsCubit>().deleteThreads(_selectedThreadIds);
      _clearSelection();
    }
  }
}
