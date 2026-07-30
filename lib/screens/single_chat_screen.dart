import 'dart:async';

import 'package:another_telephony/telephony.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/core/feedback_ui.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/cubit/mchango_cubit.dart';
import 'package:messaging/cubit/sim_card_cubit.dart';
import 'package:messaging/cubit/single_chat_cubit.dart';
import 'package:messaging/models/app_chat.dart';
import 'package:messaging/models/sim_card_state.dart';
import 'package:messaging/screens/mchango/dashboard.dart';
import 'package:messaging/screens/mchango/widgets/ongoing_banner.dart';
import 'package:messaging/screens/select_contact_screen.dart';
import 'package:messaging/screens/widgets/contact_name_text.dart';
import 'package:messaging/screens/widgets/message_bubble.dart';
import 'package:messaging/services/ac_chat_session_service.dart';
import 'package:messaging/services/contact_service.dart';
import 'package:messaging/services/notification_service.dart';
import 'package:messaging/services/mask_service.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
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
          BlocProvider(
              create: (c) => SingleChatCubit(threadId, address,
                  targetTimestamp: searchedMessage?.date)),
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

  const SingleChatScreenView(
      {super.key,
      required this.threadId,
      required this.address,
      this.initialMessage,
      this.searchedMessage});

  @override
  State<SingleChatScreenView> createState() => _SingleChatScreenViewState();
}

class _SingleChatScreenViewState extends State<SingleChatScreenView>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
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
    ActiveChatSession().enter(widget.threadId);
    WidgetsBinding.instance.addObserver(this);
    _itemPositionsListener.itemPositions.addListener(_onScroll);

    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
    }
    setupFont();
    _clearNotifications();
  }

  void setupFont() async {
    _currentScale = await UserDefaults.getTextScale();
  }

  Timer? _debounceTimer;

  void updateFontScale(double scale) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await UserDefaults.setTextScale(scale);
    });
  }
bool _isLoadingNewer = false;
bool _isLoadingOlder = false;

Timer? _olderDebounce;
Timer? _newerDebounce;

void _onScroll() {
  if (widget.searchedMessage != null && !_hasScrolledToAnchor) return;
  final positions = _itemPositionsListener.itemPositions.value;
  if (positions.isEmpty) return;

  final cubit = context.read<SingleChatCubit>();

  final visiblePositions = positions
      .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
      .toList();

  if (visiblePositions.isEmpty) return;

  final lastVisibleIndex = visiblePositions
      .map((p) => p.index)
      .fold<int>(0, (max, i) => i > max ? i : max);

  final firstVisibleIndex = visiblePositions
      .map((p) => p.index)
      .fold<int>(999999, (min, i) => i < min ? i : min);

  final totalItems = cubit.messages.length;

  // ── Load older messages ───────────────────────────────────────────────
  if (lastVisibleIndex >= totalItems - 30 && !_isLoadingOlder && !cubit.hasReachedMax) {
    _olderDebounce?.cancel();
    _olderDebounce = Timer(const Duration(milliseconds: 200), () async {
      if (!mounted) return;
      _isLoadingOlder = true;
      if(cubit.isAnchorMode){
        await cubit.loadOlderMessages();
     }else{
       await cubit.getMessages(isInitialLoad: false);
     }
      if (mounted) _isLoadingOlder = false;
    });
  }

  // ── Load newer messages (anchor mode only) ────────────────────────────
  if (firstVisibleIndex <= 5 && !_isLoadingNewer && cubit.isAnchorMode) {
    _newerDebounce?.cancel();
    _newerDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _loadNewerWithoutJump();
    });
  }
}

Future<void> _loadNewerWithoutJump() async {
  if (_isLoadingNewer) return;

  final positions = _itemPositionsListener.itemPositions.value;
  if (positions.isEmpty) return;

  final cubit = context.read<SingleChatCubit>();

  // Capture topmost visible item before load
  final firstVisible = positions
      .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
      .reduce((a, b) => a.index < b.index ? a : b);

  final anchorIndex = firstVisible.index;
  final anchorAlignment = firstVisible.itemLeadingEdge.clamp(0.0, 1.0);
  final countBefore = cubit.messages.length;

  _isLoadingNewer = true;
  await cubit.loadNewerMessages();

  final newItemsCount = cubit.messages.length - countBefore;

  if (newItemsCount > 0 && mounted) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_itemScrollController.isAttached) {
        // Shift index by how many items were prepended to cancel the visual jump
        _itemScrollController.jumpTo(
          index: anchorIndex + newItemsCount,
          alignment: anchorAlignment,
        );
      }
    });
  }

  if (mounted) _isLoadingNewer = false;
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
    _olderDebounce?.cancel();
    _newerDebounce?.cancel();
    _messageController.dispose();
    _itemPositionsListener.itemPositions.removeListener(_onScroll);
    WidgetsBinding.instance.removeObserver(this);
    ActiveChatSession().leave();
    super.dispose();
  }
bool _hasScrolledToAnchor = false;
void _scrollToAnchor(int timestamp, List<AppSmsMessage> messages) {
  // Match by both id and timestamp for precision
  int index = -1;

  if (widget.searchedMessage != null) {
    index = messages.indexWhere((m) => m.id == widget.searchedMessage!.id);
  }

  // Fallback to timestamp if id match failed
  if (index == -1) {
    index = messages.indexWhere((m) => m.date == timestamp);
  }

  if (index == -1) return;
 

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            alignment: 0.5,
          );
        }
      });
    }
  });
 Future.delayed(const Duration(milliseconds: 600), () {
    _hasScrolledToAnchor = true; 
 });
}

  final ValueNotifier<double> _textScaleNotifier = ValueNotifier<double>(1.0);
  double _baseScale = 1.0;
  double _currentScale = 1.1;

// Set limits so the UI doesn't break
  final double _minScale = 0.8;
  final double _maxScale = 2;

  @override
  Widget build(BuildContext context) {
    FeedbackUi feedbackUi = FeedbackUi(context);
    final theme = Theme.of(context);

    return BlocConsumer<SingleChatCubit, SingleChatState>(
      listener: (context, state) {
        if (state is SingleChatSendError) {
          feedbackUi.showError(state.error);
        }

        if (state is SingleChatLoaded) {
          context.read<SingleChatCubit>().markThreadAsRead();
        if (state.anchorTimestamp != null && !_hasScrolledToAnchor) {
      
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _scrollToAnchor(state.anchorTimestamp!, state.messages);
          });
        }
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
        final messages = (state is SingleChatLoaded && state.isSearching)
            ? state.messages
            : context.read<SingleChatCubit>().messages;

        bool hide = context.read<SingleChatCubit>().hideStatus;
        Widget child =  Scaffold(
          appBar: _buildAppBar(messages),
          body: Stack(
            children: [
              ValueListenableBuilder<double>(
                  valueListenable: _textScaleNotifier,
                  builder: (context, scale, child) {
                    return GestureDetector(
                      onScaleStart: (details) {
                        _baseScale = _currentScale;
                      },
                      onScaleUpdate: (details) {
                        double newScale = _baseScale * details.scale;
                        double value = newScale.clamp(_minScale, _maxScale);
                        setState(() {
                          _currentScale = value;
                        });
                        updateFontScale(value);
                      },
                      child: Column(
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
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline,
                                          ),
                                    ),
                                  ),
                                )
                              : Expanded(
                                  child: ScrollablePositionedList.builder(
                                    reverse: true,
                                    itemScrollController: _itemScrollController,
                                    itemPositionsListener: _itemPositionsListener,
                                    padding: const EdgeInsets.all(16),
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                     
              
                                      final int messageIndex = index;
              
                                      if (messageIndex < 0 ||
                                          messageIndex >= messages.length) {
                                        return const SizedBox.shrink();
                                      }
              
                                      final message = messages[messageIndex];
                                      final isOutgoing = message.isOutgoing;
                                      final isSelected =
                                          _selectedMessages.contains(message);
                                      final showDateSeparator =
                                          _shouldShowDateSeparator(
                                              messageIndex, messages);
              
                                      final isHighlighted =
                                          widget.searchedMessage == message;
              
                                      return GestureDetector(
                                        onLongPress: () =>
                                            _toggleSelection(message),
                                        onTap: () {
                                          if (_isSelectionMode) {
                                            _toggleSelection(message);
                                          }
                                        },
                                        child: MessageBubble(
                                          key: ValueKey(
                                              '${message.id}_${message.status}'),
                                          hide: hide,
                                          isOutgoing: isOutgoing,
                                          message: message,
                                          selected: isSelected,
                                          showDateSeparator: showDateSeparator,
                                          isHighlighted: isHighlighted,
                                          currentScale: _currentScale,
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
              
                                        final simCardState = state is SimCardLoaded
                                            ? state.state
                                            : null;
                                        final hasData = simCardState != null &&
                                            simCardState.allCards.isNotEmpty;
                                        final defaultSim = simCardState?.allCards
                                            .where(
                                              (sim) =>
                                                  int.tryParse(
                                                      sim.slotIndex.toString()) ==
                                                  simCardState.defaultCard,
                                            )
                                            .firstOrNull;
              
                                        return FutureBuilder<bool>(
                                            future: SmsService.isDefaultSmsApp(),
                                            builder: (context, sn) {
                                              if (sn.hasData && !sn.data!) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(
                                                      bottom: 10),
                                                  child: RichText(
                                                    textAlign: TextAlign.center,
                                                    text: TextSpan(
                                                      style: theme
                                                          .textTheme.bodyMedium
                                                          ?.copyWith(
                                                        color: theme.colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                      children: [
                                                        TextSpan(
                                                          text:
                                                              "Set as default app",
                                                          style: TextStyle(
                                                            color: theme.colorScheme
                                                                .primary,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                          recognizer:
                                                              TapGestureRecognizer()
                                                                ..onTap = () {
                                                                  SmsService
                                                                      .requestDefaultSmsRole();
                                                                },
                                                        ),
                                                        const TextSpan(
                                                            text:
                                                                " to start sending messages"),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }
                                              return Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  SizedBox(
                                                    width: 48,
                                                    height: 48,
                                                    child: _buildSimSlot(
                                                      isLoading: isLoading,
                                                      hasData:
                                                          simCardState != null &&
                                                              simCardState.allCards
                                                                  .isNotEmpty,
                                                      simCardState: simCardState,
                                                      defaultSim: defaultSim,
                                                    ),
                                                  ),
              
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          _messageController,
                                                      maxLines: 5,
                                                      minLines: 1,
                                                      enabled:
                                                          !isLoading && hasData,
                                                      onChanged: (value) =>
                                                          setState(() {}),
                                                      textCapitalization:
                                                          TextCapitalization
                                                              .sentences,
                                                      decoration: InputDecoration(
                                                        hintText: isLoading
                                                            ? 'Checking SIMs...'
                                                            : (hasData
                                                                ? 'Message'
                                                                : 'No SIM detected'),
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 20,
                                                                vertical: 10),
                                                        filled: true,
                                                        fillColor: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  28),
                                                          borderSide:
                                                              BorderSide.none,
                                                        ),
                                                        suffixIcon: Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                  right: 4),
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize.min,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              IconButton.filled(
                                                                onPressed: (isLoading ||
                                                                        !hasData ||
                                                                        _messageController
                                                                            .text
                                                                            .isEmpty)
                                                                    ? null
                                                                    : () =>
                                                                        _sendMessage(),
                                                                icon: Icon(
                                                                  Icons
                                                                      .arrow_upward,
                                                                  color: theme
                                                                      .colorScheme
                                                                      .onPrimary,
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
                                            });
                                      },
                                    ),
                                  ),
                                )
                              : const SizedBox(
                                  height: 20,
                                )
                        ],
                      ),
                    );
                  }),
                 isMpesa(widget.address)
                  ? Positioned(
                  top: 0,
                  child: MchangoActiveBanner(threadId: widget.threadId)
                  ):const SizedBox.shrink(),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: MaskService.isMonitored(widget.address)
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: FloatingActionButton.small(
                    heroTag: 'Toggle Hide',
                    onPressed: () {
                      context.read<SingleChatCubit>().toggleHide();
                      // context.read<SingleChatCubit>().loadNewerMessages();
                    },
                    child: Icon(hide
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                  ),
                )
              : null,
              // bottomNavigationBar:  AppChat.supportsReplies(widget.address)? null:  const MfichaBannerAd(adType: AdType.inChat),
        );
        return isMpesa(widget.address)?
         BlocProvider(create:   (c) => MchangoCubit(widget.threadId), child: child):
         child;
      },
    );
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
                      MaskService.maskAfterBalance(m.body, m.address).message)
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
                        forwardMessage: MaskService.maskAfterBalance(
                                body, _selectedMessages.first.address)
                            .message,
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
          ContactNameText(
              style: Theme.of(context).textTheme.titleMedium,
              rawAddress: widget.address,
              contactStream: ContactService().contactStream),
          Text('SMS', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        isMpesa(widget.address)
            ? IconButton(
                icon: const Icon(Icons.business_center_outlined),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => MchangoDashboardWrapper(threadId: widget.threadId)));
                },
              )
            : const SizedBox.shrink(),
        IconButton(
          icon: const Icon(Icons.call_outlined),
          onPressed: int.tryParse(widget.address) == null
              ? null
              : () => _makePhoneCall(widget.address),
        ),
      ],
      
    );
  }

  bool isMpesa(String address) {
    return address.toLowerCase() == 'mpesa';
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
      await context
          .read<SingleChatCubit>()
          .deleteMessages(_selectedMessages.toList());
    }
    setState(() => _selectedMessages.clear());
  }
}
