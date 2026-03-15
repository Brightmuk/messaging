import 'dart:async';

import 'package:another_telephony/telephony.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/core/feedback_ui.dart';
import 'package:messaging/cubit/payment_cubit.dart';
import 'package:messaging/cubit/sim_card_cubit.dart';
import 'package:messaging/cubit/single_chat_cubit.dart';
import 'package:messaging/models/app_chat.dart';
import 'package:messaging/models/sim_card_state.dart';
import 'package:messaging/screens/select_contact_screen.dart';
import 'package:messaging/screens/widgets/chat_bubble_ad.dart';
import 'package:messaging/screens/widgets/message_bubble.dart';
import 'package:messaging/services/contact_service.dart';
import 'package:messaging/services/notification_service.dart';
import 'package:messaging/services/redact_service.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:provider/provider.dart';
import 'package:sim_card_info/sim_info.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_message.dart';

class SingleChatScreen extends StatelessWidget {
  final String threadId;
  final String address;
  final String? initialMessage;
  final AppSmsMessage? searchedMessage;

  const SingleChatScreen(
      {super.key,
      required this.threadId,
      required this.address,
      this.searchedMessage,
      this.initialMessage});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          BlocProvider(create: (c) => SimCardCubit()),
          BlocProvider(create: (c) => SingleChatCubit(threadId, targetTimestamp: searchedMessage?.date)),
        ],
        child: SingleChatScreenView(
          threadId: threadId,
          address: address,
          initialMessage: initialMessage,
          searchedMessage: searchedMessage,
        ));
  }
}

class SingleChatScreenView extends StatefulWidget {
  final String threadId;
  final String address;
  final String? initialMessage;
  final AppSmsMessage? searchedMessage;

  const SingleChatScreenView({
    super.key,
    required this.threadId,
    required this.address,
    this.initialMessage,
    this.searchedMessage
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
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      if (mounted) {
        context.read<SingleChatCubit>().markThreadAsRead();
      }
    });
    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
    }
    _clearNotifications();
    jumpToSearchResult();
  }
  void jumpToSearchResult(){
    if(widget.searchedMessage==null) return;
    Future.delayed((const Duration(milliseconds: 500)), () {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  });
  }


  void _onScroll() {
  
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      final cubit = context.read<SingleChatCubit>();

      if (!cubit.hasReachedMax) {
        cubit.getMessages(isInitialLoad: false);
      }
    }
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
    final theme = Theme.of(context);
    bool isNoAds = Provider.of<PaymentCubit>(context).isNoAds;

    return BlocConsumer<SingleChatCubit, SingleChatState>(
      listener: (context, state) {
        if (state is SingleChatSendError) {
          feedbackUi.showError(state.error);
        }
        if (state is SingleChatLoaded) {
          context.read<SingleChatCubit>().markThreadAsRead();
        }
        if (state is SingleChatDeleted) {
          Navigator.pop(context);
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
        final messages = (state is SingleChatLoaded && state.isSearching)?
        state.messages:
        context.read<SingleChatCubit>().messages;
        
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
                        itemCount: shouldShowAds(messages.length, isNoAds)
                            ? messages.length + 1
                            : messages.length,
                        itemBuilder: (context, index) {
                          bool adsEnabled =
                              shouldShowAds(messages.length, isNoAds);

                          if (adsEnabled && index == 3) {
                            return ChatAdBubble(
                                address: messages.isNotEmpty
                                    ? messages[0].address
                                    : "");
                          }

                          final int messageIndex =
                              (adsEnabled && index > 3) ? index - 1 : index;

                          if (messageIndex < 0 ||
                              messageIndex >= messages.length) {
                            return const SizedBox.shrink();
                          }

                          final message = messages[messageIndex];
                          final isOutgoing = message.isOutgoing;
                          final isSelected =
                              _selectedMessages.contains(message);
                          final showDateSeparator =
                              _shouldShowDateSeparator(messageIndex, messages);
                         
                          return GestureDetector(
                            onLongPress: () => _toggleSelection(message),
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(message);
                              }
                            },
                            child: MessageBubble(
                              hide: hide,
                              isOutgoing: isOutgoing,
                              message: message,
                              selected: isSelected,
                              showDateSeparator: showDateSeparator,
                              isHighlighted: widget.searchedMessage?.id == message.id,
                            ),
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

                            return FutureBuilder<bool>(
                                      future: SmsService.isDefaultSmsApp(),
                                      builder: (context, sn) {
                                        if(sn.hasData && !sn.data!){
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 10),
                                            child: RichText(
                                              textAlign: TextAlign.center,
                                              text: TextSpan(
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text: "Set as default app",
                                                    style: TextStyle(
                                                      color: theme.colorScheme.primary,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    recognizer: TapGestureRecognizer()
                                                      ..onTap = () {
                                                        SmsService.requestDefaultSmsRole();
                                                      },
                                                  ),
                                                  const TextSpan(text: " to start sending messages"),
                                                ],
                                              ),
                                            ),
                                          );
                                        }
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
                                
                                    Expanded(
                                          child: TextField(
                                            controller: _messageController,
                                            maxLines: 5,
                                            minLines: 1,
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
                                                                  .text.isEmpty)
                                                          ? null
                                                          : () => _sendMessage(),
                                                      icon: Icon(
                                                        Icons.arrow_upward,
                                                        color:
                                                            theme.colorScheme.onPrimary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                
                                    // --- TEXT FIELD SECTION ---
                                    const SizedBox(width: 8),
                                  ],
                                );
                              }
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

  bool shouldShowAds(int messageLength, bool isNoAds) {
    return RedactService.isMonitored(widget.address) &&
        messageLength > 5 &&
        !isNoAds;
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
                  .map((m) =>
                      RedactService.redactAfterBalance(m.body, m.address))
                  .join('\n');
              Clipboard.setData(ClipboardData(text: text));
              setState(() => _selectedMessages.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')));
            },
          ),
          if (_selectedMessages.length == 1)
            IconButton(
              icon: const Icon(Icons.forward_to_inbox_outlined),
              onPressed: () {
                final body = _selectedMessages.first.body;

                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SelectContactScreen(
                        isForwarding: true,
                        forwardMessage: RedactService.redactAfterBalance(
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


    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ContactService().getName(widget.address)),
          Text('SMS', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        
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
  }

  bool _shouldShowDateSeparator(int index, List<AppSmsMessage> messages) {
    if (index == messages.length - 1) return true;

    final currentMsgDate =
        DateTime.fromMillisecondsSinceEpoch(messages[index].date);
    final olderMsgDate =
        DateTime.fromMillisecondsSinceEpoch(messages[index + 1].date);

    return currentMsgDate.day != olderMsgDate.day ||
        currentMsgDate.month != olderMsgDate.month ||
        currentMsgDate.year != olderMsgDate.year;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final isDefault = await SmsService.isDefaultSmsApp();
    if (!isDefault) {
      SmsService.requestDefaultSmsRole();
      return;
    }
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
      await context.read<SingleChatCubit>().deleteMessages(_selectedMessages.toList());
    }
    setState(() => _selectedMessages.clear());
  }
}
