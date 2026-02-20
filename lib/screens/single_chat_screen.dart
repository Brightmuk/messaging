import 'package:another_telephony/telephony.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/core/feedback_ui.dart';
import 'package:messaging/core/utils/date_formatter.dart';
import 'package:messaging/cubit/sim_card_cubit.dart';
import 'package:messaging/cubit/single_chat_cubit.dart';
import 'package:messaging/models/app_chat.dart';
import 'package:messaging/models/sim_card_state.dart';
import 'package:messaging/screens/select_contact_screen.dart';
import 'package:messaging/services/contact_service.dart';
import 'package:messaging/services/notification_service.dart';
import 'package:messaging/services/redact_service.dart';
import 'package:provider/provider.dart';
import 'package:sim_card_info/sim_info.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_message.dart';

class SingleChatScreen extends StatelessWidget {
  final String threadId;
  final String address;
  final String? initialMessage;
  const SingleChatScreen(
      {super.key,
      required this.threadId,
      required this.address,
      this.initialMessage});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          BlocProvider(create: (c) => SimCardCubit()),
          BlocProvider(create: (c) => SingleChatCubit(threadId)),
        ],
        child: SingleChatScreenView(
          threadId: threadId,
          address: address,
          initialMessage: initialMessage,
        ));
  }
}

class SingleChatScreenView extends StatefulWidget {
  final String threadId;
  final String address;
  final String? initialMessage;

  const SingleChatScreenView({
    super.key,
    required this.threadId,
    required this.address,
    this.initialMessage,
  });

  @override
  State<SingleChatScreenView> createState() => _SingleChatScreenViewState();
}

class _SingleChatScreenViewState extends State<SingleChatScreenView>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final telephony = Telephony.instance;
  final Set<AppSmsMessage> _selectedMessages = {};
  bool get _isSelectionMode => _selectedMessages.isNotEmpty;

// Search State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _toggleSelection(AppSmsMessage message) {
    setState(() {
      if (_selectedMessages.contains(message)) {
        _selectedMessages.remove(message);
      } else {
        _selectedMessages.add(message);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    context.read<SingleChatCubit>().markThreadAsRead();
    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
    }
    _clearNotifications();
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    FeedbackUi feedbackUi = FeedbackUi(context);
    return BlocConsumer<SingleChatCubit, SingleChatState>(
      listener: (context, state) {
        if (state is SingleChatSendError) {
          feedbackUi.showError(state.error);
        }
        if (state is SingleChatLoaded && state.isUpdate) {
          context.read<SingleChatCubit>().markThreadAsRead();
        }
      },
      builder: (context, state) {
        if (state is SingleChatLoading) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        } else if (state is SingleChatError) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text("Error loading messages")),
          );
        }
        final allMessages = context.read<SingleChatCubit>().messages;

        // Filter messages based on search
        final messages = allMessages.where((m) {
          return m.body.toLowerCase().contains(_searchQuery);
        }).toList();
        bool hide = context.read<SingleChatCubit>().hideStatus;
        return Scaffold(
          appBar: _buildAppBar(messages),
          body: Column(
            children: [
              messages.isEmpty
                  ? Expanded(
                      child: Center(
                        child: Text(
                          'No messages',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ),
                    )
                  : Expanded(
                      child: ListView.builder(
                        reverse: true,
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isOutgoing = message.isOutgoing;
                          final isSelected =
                              _selectedMessages.contains(message);
                          final showDateSeparator =
                              _shouldShowDateSeparator(index, messages);

                          return GestureDetector(
                            onLongPress: () => _toggleSelection(message),
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(message);
                              }
                            },
                            child: _buildMessageBubble(
                                message: message,
                                isOutgoing: isOutgoing,
                                showDateSeparator: showDateSeparator,
                                hide: hide,
                                selected: isSelected),
                          );
                        },
                      ),
                    ),
              AppChat.supportsReplies(widget.address)
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: SafeArea(
                        child: BlocBuilder<SimCardCubit, SimCardState>(
                          builder: (context, state) {
                            final isLoading = state is SimCardInitial;

                            final simCardState =
                                state is SimCardLoaded ? state.state : null;
                            final hasData = simCardState != null &&
                                simCardState.allCards.isNotEmpty;
                            final defaultSim = simCardState?.allCards
                                .where(
                                  (sim) =>
                                      int.tryParse(sim.slotIndex.toString()) ==
                                      simCardState.defaultCard,
                                )
                                .firstOrNull;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: _buildSimSlot(
                                    isLoading: isLoading,
                                    hasData: simCardState != null &&
                                        simCardState.allCards.isNotEmpty,
                                    simCardState: simCardState,
                                    defaultSim: defaultSim,
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // --- TEXT FIELD SECTION ---
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    maxLines: 5,
                                    minLines: 1,
                                    // Disable input if loading or if no SIM cards are available
                                    enabled: !isLoading && hasData,
                                    onChanged: (value) => setState(() {}),
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: InputDecoration(
                                      hintText: isLoading
                                          ? 'Checking SIMs...'
                                          : (hasData
                                              ? 'Message'
                                              : 'No SIM detected'),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 10),
                                      filled: true,
                                      fillColor: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(28),
                                        borderSide: BorderSide.none,
                                      ),
                                      suffixIcon: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 4),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            IconButton.filled(
                                              onPressed: (isLoading ||
                                                      !hasData ||
                                                      _messageController
                                                          .text.isEmpty ||
                                                      (state
                                                          is SingleChatSending))
                                                  ? null
                                                  : () => _sendMessage(),
                                              icon: (state is SingleChatSending)
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white),
                                                    )
                                                  : const Icon(
                                                      Icons.arrow_upward,
                                                      color: Colors.white,
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    )
                  : const SizedBox(
                      height: 50,
                    )
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: RedactService.isMonitored(widget.address)
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: FloatingActionButton.small(
                    heroTag: 'Toggle Hide',
                    onPressed: () {
                      context.read<SingleChatCubit>().toggleHide();
                    },
                    child: Icon(hide
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildMessageBubble({
    required AppSmsMessage message,
    required bool isOutgoing,
    required bool showDateSeparator,
    required bool hide,
    required bool selected,
  }) {
    return Column(
      children: [
        if (showDateSeparator) _buildDateSeparator(message.date),
        Align(
          alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(
                  bottom: 4,
                  left: isOutgoing ? 50 : 12, // More space on the opposite side
                  right: isOutgoing ? 12 : 50,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : isOutgoing
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isOutgoing ? 20 : 4),
                    bottomRight: Radius.circular(isOutgoing ? 4 : 20),
                  ),
                  boxShadow: selected
                      ? [BoxShadow(color: Colors.black12, blurRadius: 4)]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Message Text
                    Text(
                      hide
                          ? RedactService.redactBalances(
                              message.body, message.address)
                          : message.body,
                      style: TextStyle(
                        color: isOutgoing && !selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 2. Metadata Row (Time + Ticks)
                    Text(
                      formatMessageTime(message.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: isOutgoing && !selected
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimary
                                    .withOpacity(0.8)
                                : Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              if (isOutgoing) ...[
                const SizedBox(width: 4),
                GestureDetector(
                    onTap: message.status == MessageStatus.failed
                        ? () => _handleRetry(message)
                        : null,
                    child: _buildStatusIcon(message.status)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _handleRetry(AppSmsMessage message) async {
    _sendMessage();
  }

// Helper to show the correct status icon
  Widget _buildStatusIcon(MessageStatus status) {
    final theme = Theme.of(context);
    switch (status) {
      case MessageStatus.unknown:
        return const SizedBox();
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 15, color: theme.primaryColor);
      case MessageStatus.sent:
        return Icon(Icons.done,
            size: 15, color: theme.colorScheme.onSurfaceVariant);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline,
            size: 15, color: Colors.redAccent);
      case MessageStatus.pending:
        return Icon(Icons.access_time,
            size: 15, color: theme.colorScheme.onSurfaceVariant);
    }
  }

  AppBar _buildAppBar(List<AppSmsMessage> messages) {
    // 1. SELECTION MODE
    if (_isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _selectedMessages.clear()),
        ),
        title: Text('${_selectedMessages.length} selected'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy_outlined),
            onPressed: () {
              final text = _selectedMessages
                  .map((m) => RedactService.redactBalances(m.body, m.address))
                  .join('\n');
              Clipboard.setData(ClipboardData(text: text));
              setState(() => _selectedMessages.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')));
            },
          ),
          if (_selectedMessages.length == 1) // Forward only for single
            IconButton(
              icon: const Icon(Icons.forward_to_inbox_outlined),
              onPressed: () {
                final body = _selectedMessages.first.body;

                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SelectContactScreen(
                        isForwarding: true,
                        forwardMessage: RedactService.redactBalances(
                            body, _selectedMessages.first.address),
                      ),
                    ));
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteSelectedMessages(),
          ),
        ],
      );
    }

    // 2. SEARCH MODE
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _isSearching = false;
            _searchQuery = '';
            _searchController.clear();
          }),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Search messages...', border: InputBorder.none),
          onChanged: (value) =>
              setState(() => _searchQuery = value.toLowerCase()),
        ),
      );
    }

    // 3. NORMAL MODE
    return AppBar(
      title: InkWell(
        // Tap title to search (common UX) or use search icon
        onTap: () => setState(() => _isSearching = true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ContactService().getName(widget.address)),
            Text('SMS', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _isSearching = true)),
        IconButton(
          icon: const Icon(Icons.call_outlined),
          onPressed: int.tryParse(widget.address) == null
              ? null
              : () => _makePhoneCall(widget.address),
        ),
      ],
    );
  }

  Widget _buildSimSlot({
    required bool isLoading,
    required bool hasData,
    AppSimCardState? simCardState,
    SimInfo? defaultSim,
  }) {
    if (isLoading) {
      return const Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)));
    }

    if (!hasData || simCardState == null) {
      return const Icon(Icons.sim_card_alert_outlined, color: Colors.grey);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        PopupMenuButton<int>(
          initialValue: simCardState.defaultCard,
          icon: Icon(
            Icons.sim_card_outlined,
            color: AppSimCardState.getSimcardColor(defaultSim?.carrierName),
          ),
          onSelected: (int sim) async {
            await context.read<SimCardCubit>().setDefaultSim(sim);
          },
          itemBuilder: (BuildContext context) {
            return simCardState.allCards.map<PopupMenuEntry<int>>((sim) {
              int slot = int.tryParse(sim.slotIndex.toString()) ?? -1;
              return PopupMenuItem<int>(
                value: slot,
                child: ListTile(
                  leading: Icon(Icons.sim_card,
                      color: AppSimCardState.getSimcardColor(sim.carrierName)),
                  title: Text('SIM ${slot + 1} (${sim.displayName})'),
                ),
              );
            }).toList();
          },
        ),
        if (simCardState.defaultCard != null)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              height: 14,
              width: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppSimCardState.getSimcardColor(defaultSim?.carrierName),
              ),
              child: Center(
                child: Text(
                  (simCardState.defaultCard! + 1).toString(),
                  style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void showDefaultSmsDialog() {
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
            child: const Text('Not Now '),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<SingleChatCubit>().setAsDefaultApp();
            },
            child: const Text('Set as Default'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    context.read<SingleChatCubit>().sendMessage(widget.address, message);
    _messageController.clear();
    // await context.read<SingleChatCubit>().markThreadAsRead();
  }

  Widget _buildDateSeparator(int timestamp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              formatMessageDate(timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  bool _shouldShowDateSeparator(int index, List<AppSmsMessage> messages) {
    if (index == 0) return true;

    final currentDate =
        DateTime.fromMillisecondsSinceEpoch(messages[index].date);
    final previousDate =
        DateTime.fromMillisecondsSinceEpoch(messages[index - 1].date);

    return currentDate.day != previousDate.day ||
        currentDate.month != previousDate.month ||
        currentDate.year != previousDate.year;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $launchUri';
    }
  }

  Future<void> _deleteSelectedMessages() async {
    final count = _selectedMessages.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count message(s)?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<SingleChatCubit>().deleteMessages(_selectedMessages);
    }
    setState(() => _selectedMessages.clear());
  }
}
