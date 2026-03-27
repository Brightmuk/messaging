import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/core/brand_palette.dart';
import 'package:messaging/core/feedback_ui.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/cubit/chats_cubit.dart';
import 'package:messaging/cubit/payment_cubit.dart';
import 'package:messaging/models/app_chat.dart';
import 'package:messaging/screens/global_search_page.dart';
import 'package:messaging/screens/settings_screen.dart';
import 'package:messaging/screens/setup_doa.dart';
import 'package:messaging/screens/single_chat_screen.dart';
import 'package:messaging/core/utils/date_formatter.dart';
import 'package:messaging/screens/widgets/ad_free_tile.dart';
import 'package:messaging/screens/widgets/banner_ad.dart';
import 'package:messaging/screens/widgets/chats_loading_widget.dart';
import 'package:messaging/screens/widgets/contact_name_text.dart';
import 'package:messaging/screens/widgets/limited_access_tile.dart';
import 'package:messaging/screens/widgets/rating_dialog.dart';
import 'package:messaging/services/contact_service.dart';
import 'package:messaging/services/notification_service.dart';
import 'package:messaging/services/rating_limiter.dart';
import 'package:messaging/services/mask_service.dart';
import 'package:messaging/services/transaction_summary_service.dart';
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
      NotificationService().handleInitialMessage();
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
    if(!await NotificationService.canShowOverlay() && await UserDefaults.canShowOverlayPrompt()){
      Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;
        showOverlayBottomSheet(context);
      }
      );
    }

  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _clearNotifications();
      context.read<ChatsCubit>().loadChats(isInitialLoad: true);
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
    bool isNoAds = Provider.of<PaymentCubit>(context).isNoAds;

    return Scaffold(
      body: BlocBuilder<ChatsCubit, ChatsState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: context.read<ChatsCubit>().loadChats,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                if (state is ChatsLoading ||
                    state is ChatsInitial ||
                    state is ChatsError ||
                    state is PermissionRevoked)
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
                if (state is PermissionRevoked)
                  SliverFillRemaining(child: _buildPermissionsPrompt(context))
                
                else if (state is ChatsLoaded)
                  state.chats.isEmpty
                      ? const SliverFillRemaining(
                          child: ChatsLoadingWidget(isEmptyState: true))
                      : SliverList(
                          delegate:  SliverChildBuilderDelegate(
                                (context, index) {
                                  final isDefault = state.isDefaultApp;
                                  
                                  // 1. Handle the Top "Limited Access" tile for non-default users
                                  if (!isDefault && index == 0) {
                                    return LimitedAccessTile(
                                      onRequest: () => context.read<ChatsCubit>().requestDefaultRole(),
                                    );
                                  }

                                  // Base chat index adjustment
                                  int chatIndex = isDefault ? index : index - 1;

                                  // 2. Handle the Ad-Free Upsell Tile (Only if ads are enabled)
                                  if (!isNoAds) {
                                    // We'll place the AdFreeTile at index 6 (Default) or 7 (Non-Default)
                                    final adFreeIndex = isDefault ? 6 : 7;

                                    if (index == adFreeIndex) {
                                      return const AdFreeTile();
                                    }

                                    // If we are past the AdFreeTile, we subtract 1 from chatIndex 
                                    // to "skip" that slot and fetch the correct chat from the list.
                                    if (index > adFreeIndex) {
                                      chatIndex -= 1;
                                    }
                                  }

                                  // 3. Safety Check
                                  if (chatIndex >= state.chats.length || chatIndex < 0) {
                                    return null;
                                  }

                                  // 4. Build the actual chat tile
                                  return isDefault
                                      ? _buildChatTile(state.chats[chatIndex])
                                      : _buildPrivacyVaultTile(state.chats[chatIndex], context);
                                },
                                childCount: calculateChildCount(
                                  state.chats.length,
                                  state.isDefaultApp,
                                  isNoAds,
                                ),
                              ),
                        )
                else
                  const SliverFillRemaining(child: ChatsLoadingWidget())
                  
              ],
            ),
          );
        },
      ),
      floatingActionButton: BlocBuilder<ChatsCubit, ChatsState>(
        builder: (context, state) {
          bool isDefault = state is ChatsLoaded ? state.isDefaultApp : false;
          
          return FloatingActionButton.extended(
            label: const Text('New'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
             
              // NotificationService.showOverlay(address: "Mpesa", text: "TKFL9ADWCV has been successfully reversed on 8/3/26 at 10:48 PM and Ksh50.00 is debited from your M-PESA account. New M-PESA account balance is Ksh3,920.00");
              // SmsService().generateTestData();
              if (isDefault) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SelectContactScreen()));
              } else {
                context.read<ChatsCubit>().requestDefaultRole();
              }
            },
          );
        },
      ),
      bottomNavigationBar:  SafeArea(child: MfichaBannerAd()),
    );
  }

  int calculateChildCount(int chatsLength, bool isDefaultApp, bool isNoAds) {
  // If no chats and it's the default app, show nothing (or an empty state)
  if (chatsLength == 0 && isDefaultApp) return 0;

  int totalCount = chatsLength;

  // Add 1 for the LimitedAccessTile if not the default app
  if (!isDefaultApp) {
    totalCount += 1;
  }

  // Add 1 for the AdFreeTile only if ads are active and the list is long enough
  if (!isNoAds && chatsLength >= 6) {
    totalCount += 1;
  }

  return totalCount;
}



  Widget _buildPermissionsPrompt(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_person_outlined,
              size: 80, color: theme.colorScheme.primary.withOpacity(0.8)),
          const SizedBox(height: 32),
          Text("Messaging & Privacy features off",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const Text(
            "To manage your messages and enable real-time balance masking, M-Ficha needs to be your default messenger",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 50),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.read<ChatsCubit>().requestDefaultRole(),
              child: const Text("Set as Default App"),
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
                      : Colors.transparent
                      ),
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
                      MaskService.maskAfterBalance(
                          chat.lastMessage ?? '', chat.address).message,
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
  Widget _buildPrivacyVaultTile(AppChat chat, BuildContext context) {
  final theme = Theme.of(context);
  final bool isSelected = _selectedThreadIds.contains(chat.threadId);
  final palette = getBrandPalette(chat.address, context);
  final summary = TransactionSummary.parse(chat.lastMessage??'');


  return GestureDetector(
    
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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(20),
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color:  isSelected
                  ? theme.colorScheme.primaryContainer : palette.background,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.accent.withOpacity(0.1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Brand + Privacy Shield
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   isSelected? 
                   CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primary,
                    child:Icon(Icons.check, color: theme.colorScheme.onPrimary)
                        
                  ):
                    Icon(Icons.security, size: 16, color: palette.accent),
                  const SizedBox(width: 8),
                  Text(
                    chat.address,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: palette.accent,
                    ),
                  ),
                ],
              ),
              _buildPrivacyBadge(palette),
            ],
          ),
          const SizedBox(height: 20),
      
          // 2. Sanitized Content
          Text(
            summary.action == "Checked balance" 
                ? "Account balance check performed." 
                : "${summary.action} ${summary.amount} to ${summary.name}",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
      
          // 3. The "Masked" Preview & Show Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Visual Redaction Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text("Balance: ", style: theme.textTheme.bodySmall),
                    Container(
                      width: 60,
                      height: 10,
                      decoration: BoxDecoration(
                        color: palette.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              
              // The "Show" Action
              summary.isBalanceCheck? const SizedBox.shrink(): TextButton.icon(
                onPressed: () => _showPrivacyDialog(context, chat, palette),
                style: TextButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text("Receipt", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
Widget _buildPrivacyBadge(BrandPalette palette) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: ShapeDecoration(
      // Gradient adds that "Premium/Modern" fintech feel
      gradient: LinearGradient(
        colors: [
          palette.accent.withOpacity(0.15),
          palette.accent.withOpacity(0.05),
        ],
      ),
      shape: StadiumBorder(
        side: BorderSide(color: palette.accent.withOpacity(0.2), width: 1),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing-style dot to show the "Privacy Shield" is active
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: palette.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: palette.accent.withOpacity(0.4),
                blurRadius: 4,
                spreadRadius: 1,
              )
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          "SECURE VIEW",
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: palette.accent,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );
}
void _showPrivacyDialog(BuildContext context, AppChat chat, BrandPalette palette) {
  final theme = Theme.of(context);
  final summary = TransactionSummary.parse(chat.lastMessage??'');

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: AlertDialog(
        backgroundColor: Colors.transparent, // Transparent to show the bubble
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. The "Vault" Status Indicator above the bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    "SECURE TRANSACTION VIEW",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            // 2. The Chat Bubble
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        summary.action.toUpperCase(),
                        style: TextStyle(
                          color: palette.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        "Just Now", // You can pass the actual time here
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // The "Message" Body
                  Text(
                    MaskService.maskAfterBalance(chat.lastMessage??'', chat.address).message,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      letterSpacing: 0.2,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action Row: Copy Trans ID
                  // _buildCopyIdButton(rawMessage, palette, theme),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 3. Dismiss Button
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.clear, color: Colors.white, size: 48),
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
