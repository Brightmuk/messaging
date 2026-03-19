import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/core/utils/date_formatter.dart';
import 'package:messaging/cubit/single_chat_cubit.dart';
import 'package:messaging/models/app_message.dart';
import 'package:messaging/services/redact_service.dart';

class MessageBubble extends StatefulWidget {
    final AppSmsMessage message;
    final bool isOutgoing;
    final bool showDateSeparator;
    final bool hide;
    final bool selected;
    final bool isHighlighted;
  const MessageBubble({super.key, required this.hide, required this.isOutgoing, required this.message, required this.selected, required this.showDateSeparator, this.isHighlighted = false});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showMore = false;
  bool _shouldHighlight = false;

  @override
  void initState(){
    super.initState();
    _showMore = !widget.hide;
    fadeHighlight();
  }
  void fadeHighlight(){
    _shouldHighlight = widget.isHighlighted;
    if (widget.isHighlighted) {
      // Trigger the fade effect shortly after the bubble is rendered
       Future.delayed(const Duration(seconds: 1), () {
            if (mounted) setState(() => _shouldHighlight = false);
          });
    }
  }
  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.hide != widget.hide) {
      setState(() {
        _showMore = !widget.hide;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String redactedMessage = RedactService.redactAfterBalance(
      widget.message.body, widget.message.address);
     return Column(
      children: [
        if (widget.showDateSeparator) _buildDateSeparator(widget.message.date),
        Align(
          alignment: widget.isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: widget.isOutgoing
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(
                  bottom: 4,
                  left: widget.isOutgoing ? 50 : 12, // More space on the opposite side
                  right: widget.isOutgoing ? 12 : 50,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                decoration: BoxDecoration(
                  color:  
                   widget.selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : widget.isOutgoing
                          ? (_shouldHighlight 
            ? const Color.fromARGB(255, 177, 127, 233) :
                            Theme.of(context).colorScheme.primary)
                          : (_shouldHighlight 
            ? Colors.purple : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(widget.isOutgoing ? 20 : 4),
                    bottomRight: Radius.circular(widget.isOutgoing ? 4 : 20),
                  ),
                  boxShadow: widget.selected
                      ? [BoxShadow(color: Colors.black12, blurRadius: 4)]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Message Text
                   
                    RichText(
                    text: TextSpan(
                     style: TextStyle(
                        color: widget.isOutgoing && !widget.selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      children: [
                        TextSpan(text: _showMore? widget.message.body: redactedMessage),

                        !isRedactedMessage(redactedMessage) || !widget.hide || !RedactService.isMonitored(widget.message.address)? const TextSpan(): TextSpan(
                          text:  _showMore? " hide": " see more",
                          style: const TextStyle(
                            color: Colors.blue, 
                            fontWeight: FontWeight.bold
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              setState(() {
                                _showMore = !_showMore; 
                              });
                            },
                        ),
                      ],
                    ),
                  ),
                    const SizedBox(height: 4),
                    // 2. Metadata Row (Time + Ticks)
                    Text(
                      formatMessageTime(widget.message.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: widget.isOutgoing && !widget.selected
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
              Padding(
               padding: EdgeInsets.only(right: widget.isOutgoing ? 12 : 0, left: widget.isOutgoing ? 0 : 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment:widget.isOutgoing
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                 
                 
                  children: [
                  if (widget.isOutgoing) ...[
                  const SizedBox(width: 2),
                  GestureDetector(
                      onTap: widget.message.status == MessageStatus.failed
                          ? () => _handleRetry(widget.message)
                          : null,
                      child: _buildStatusIcon(widget.message.status)),
                ],
                
                  ],
                ),
              )
              
            ],
          ),
        ),
      ],
    );
  }
  bool isRedactedMessage(String redactedMessage){
    return widget.message.body != redactedMessage;
  }
    void _handleRetry(AppSmsMessage message) async {
       final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message not sent'),
        content: const Text('Retry sending this message?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Retry')),
        ],
      ),
    );

    if (confirm == true) {
      context.read<SingleChatCubit>().retrySend(widget.message);
    }
    
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

  Widget _buildStatusIcon(MessageStatus status) {
    final theme = Theme.of(context);
    switch (status) {
      case MessageStatus.unknown:
        return const SizedBox();
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 15, color: theme.colorScheme.primary);
      case MessageStatus.sent:
        return Icon(Icons.done,
            size: 15, color: theme.colorScheme.onSurfaceVariant);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline,
            size: 18, color: Colors.redAccent);
      case MessageStatus.pending:
        return Icon(Icons.access_time,
            size: 15, color: theme.colorScheme.onSurfaceVariant);
    }
  }
}