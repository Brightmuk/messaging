import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/core/utils/date_formatter.dart';
import 'package:messaging/cubit/single_chat_cubit.dart';
import '../models/sms_message.dart';

class SingleChatScreen extends StatelessWidget {
  final String threadId;
  final String address;
  const SingleChatScreen(
      {super.key, required this.threadId, required this.address});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
        child: SingleChatScreenView(threadId: threadId, address: address),
        create: (c) => SingleChatCubit(threadId));
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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      body: BlocBuilder<SingleChatCubit, SingleChatState>(
        builder: (context, state) {
          if (state is SingleChatLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is SingleChatError) {
            return const Center(child: Text('Something went wrong'));
          }
          final messages = (state as SingleChatLoaded).messages;

          return Column(
            children: [
              messages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Message',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed:
                            (state is SingleChatSending) ? null : _sendMessage,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: const CircleBorder(),
                        ),
                        child: (state is SingleChatSending)
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
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
