import 'package:another_telephony/telephony.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/core/feedback_ui.dart';
import 'package:messaging/core/utils/date_formatter.dart';
import 'package:messaging/cubit/single_chat_cubit.dart';
import 'package:messaging/models/sim_card_state.dart';
import 'package:messaging/services/sms_service.dart';
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

class _SingleChatScreenViewState extends State<SingleChatScreenView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final telephony = Telephony.instance;
  final Future<AppSimCardState> _simState = SmsService().getSimState();

  

  @override
  void initState() {
    super.initState();
    context.read<SingleChatCubit>().markThreadAsRead();
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
            Text(widget.address),
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
            onPressed: () {
              // TODO: Implement call functionality
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
        listener: (context, state){
          if(state is SingleChatSendError){
           feedbackUi.showError(state.error);
          }
          if(state is SingleChatLoaded && state.isUpdate){
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
                                        message.body,
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
                    if(sn.connectionState == ConnectionState.waiting || sn.hasError) return const SizedBox();
                    AppSimCardState simCardState = sn.data!;
                   
                      return Row(
                        children: [
                         
                        Stack(
                              children: [
                                IconButton(
                                        onPressed: () {},
                                        icon: Icon(Icons.sim_card_outlined,
                                            color: Theme.of(context).colorScheme.primary),
                                      ),
                                     simCardState.defaultCard !=null? Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Text((simCardState.defaultCard.toString()),)): const SizedBox(),
                              ],
                            ),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              maxLines: 5,
                              minLines: 1,
                              onChanged: (value) {
                                setState(() {
                                  
                                });
                              },
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: 'Message',
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                // Use filled background with rounded corners (Pill shape)
                                filled: true,
                                
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide.none,
                                ),
                                // The Send Button nested inside the input
                                suffixIcon: Column(
                                  children: [
                                    IconButton.filled(
                                      color: Colors.white,
                                     padding: const EdgeInsets.all(2),
                                     
                                      onPressed: (state is SingleChatSending) || _messageController.text.isEmpty || !simCardState.canSend()
                                          ? null
                                          : _sendMessage,
                                      icon: (state is SingleChatSending)
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons
                                              .arrow_upward), // M3 uses upward arrow for "Send"
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  ),
                ),
              )
            ],
          );
        },
      ),
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
}
