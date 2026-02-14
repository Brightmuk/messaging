import 'package:another_telephony/telephony.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/core/feedback_ui.dart';
import 'package:messaging/core/utils/date_formatter.dart';
import 'package:messaging/cubit/single_chat_cubit.dart';
import 'package:messaging/models/sim_card_state.dart';
import 'package:messaging/services/contact_service.dart';
import 'package:messaging/services/notification_service.dart';
import 'package:messaging/services/redact_service.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:sim_card_info/sim_info.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sms_message.dart';

class SingleChatScreen extends StatelessWidget {
  final String threadId;
  final String address;
  const SingleChatScreen(
      {super.key, required this.threadId, required this.address});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
        create: (c) => SingleChatCubit(threadId),
        child: SingleChatScreenView(threadId: threadId, address: address));
  }
}

class SingleChatScreenView extends StatefulWidget {
  final String threadId;
  final String address;

  const SingleChatScreenView({
    super.key,
    required this.threadId,
    required this.address,
  });

  @override
  State<SingleChatScreenView> createState() => _SingleChatScreenViewState();
}

class _SingleChatScreenViewState extends State<SingleChatScreenView> with WidgetsBindingObserver{
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final telephony = Telephony.instance;
  Future<AppSimCardState> _simState = SmsService().getSimState();

  @override
  void initState() {
    super.initState();
    context.read<SingleChatCubit>().markThreadAsRead();
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ContactService().getName(widget.address)),
            Text(
              'SMS',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: int.tryParse(widget.address) == null
                ? null
                : () {
                    _makePhoneCall(widget.address);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Implement more options
            },
          ),
        ],
      ),
      body: BlocConsumer<SingleChatCubit, SingleChatState>(
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
            return const Center(child: CircularProgressIndicator());
          } else if (state is SingleChatError) {
            return const Center(child: Text('Something went wrong'));
          }
          final messages = context.read<SingleChatCubit>().messages;
          bool hide = context.read<SingleChatCubit>().hideStatus;
          
          return Column(
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
                          final isSent = message.isSent;
                          final showDateSeparator =
                              _shouldShowDateSeparator(index, messages);

                          return Column(
                            children: [
                              if (showDateSeparator)
                                _buildDateSeparator(message.date),
                              Align(
                                alignment: isSent
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.75,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSent
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        hide? RedactService.redactBalances(message.body, message.address): message.body,
                                        style: TextStyle(
                                          color: isSent
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatMessageTime(message.date),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: isSent
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onPrimary
                                                      .withOpacity(0.7)
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .outline,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  
                ),
                child: SafeArea(
                  child: FutureBuilder<AppSimCardState>(
                    future: _simState,
                    builder: (context, sn) {
                      // 1. Setup State Variables
                      final bool isLoading =
                          sn.connectionState == ConnectionState.waiting;
                     
                      final bool hasData =
                          sn.hasData && sn.data!.allCards.isNotEmpty;

                      final simCardState = sn.data;
                      final defaultSim = hasData
                          ? simCardState!.allCards
                              .where(
                                (sim) =>
                                    int.tryParse(sim.slotIndex.toString()) ==
                                    simCardState.defaultCard,
                              )
                              .firstOrNull
                          : null;

                      // 2. Return a consistent Row structure
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment
                            .end, // Aligns items to bottom as text grows
                        children: [
                          // --- SIM SELECTOR SECTION ---
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: _buildSimSlot(
                              isLoading: isLoading,
                              hasData: hasData,
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
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: isLoading
                                    ? 'Checking SIMs...'
                                    : (hasData ? 'Message' : 'No SIM detected'),
                                contentPadding: const EdgeInsets.symmetric(
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
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton.filled(
                                        onPressed: (isLoading ||
                                                !hasData ||
                                                _messageController
                                                    .text.isEmpty ||
                                                (state is SingleChatSending))
                                            ? null
                                            : () => _sendMessage(),
                                        icon: (state is SingleChatSending)
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white),
                                              )
                                            : const Icon(Icons.arrow_upward),
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
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton:  RedactService.isMonitored(widget.address)? BlocBuilder<SingleChatCubit, SingleChatState>(
        builder: (context, state) {

          bool hide = context.read<SingleChatCubit>().hideStatus;
          return Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: FloatingActionButton.small(
                    heroTag: 'Toggle Hide',
                    onPressed: () {
                      context.read<SingleChatCubit>().toggleHide();
                    },
                    child:  Icon(hide? Icons.visibility_off_outlined: Icons.visibility_outlined ),
                  ),
            );
        },
      ):null,
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
          onSelected: (int sim) {
            setState(() {
              _simState = SmsService()
                  .setDefaultSim(sim)
                  .then((v) => SmsService().getSimState());
            });
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
            child: const Text('Not Now'),
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
}
