import 'package:flutter/material.dart';
import 'package:messaging/services/contact_service.dart';

class ContactNameText extends StatelessWidget {
  final bool unread;
  final String rawAddress;
  final Stream<int> contactStream;
  final TextStyle? style;

  const ContactNameText(
      {super.key,
      this.unread = false,
      required this.rawAddress,
      required this.contactStream,
       this.style
      });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: contactStream,
      builder: (context, snapshot) {
        String displayName = ContactService().getName(rawAddress);
        return ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            // 1. ADD THIS: This prevents the "Stack" from jumping around
            layoutBuilder:
                (Widget? currentChild, List<Widget> previousChildren) {
              return Stack(
                alignment: Alignment.centerLeft, // Anchor to the left
                children: <Widget>[
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            transitionBuilder: (Widget child, Animation<double> animation) {
              final isEntering = child.key == ValueKey<String>(displayName);

              // Slide from bottom (in) or to top (out)
              final offsetAnimation = Tween<Offset>(
                begin: isEntering ? const Offset(0.0, 1.0) : Offset.zero,
                end: isEntering ? Offset.zero : const Offset(0.0, -1.0),
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ));

              return SlideTransition(
                position: offsetAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: Text(
              displayName,
              key: ValueKey<String>(displayName),
              // 2. ADD THIS: Ensure text doesn't wrap or stretch unexpectedly
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: style ?? Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                  ),
            ),
          ),
        );
      },
    );
  }
}
