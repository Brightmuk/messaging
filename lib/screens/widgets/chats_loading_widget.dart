import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ChatsLoadingWidget extends StatefulWidget {
  final bool isEmptyState;
  const ChatsLoadingWidget({super.key, this.isEmptyState = false});

  @override
  State<ChatsLoadingWidget> createState() => _ChatsLoadingWidgetState();
}

class _ChatsLoadingWidgetState extends State<ChatsLoadingWidget> {
  Timer ? _timer;
  bool stopShimmer = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        if(widget.isEmptyState) {
           setState(() {
          stopShimmer = true;
        });
      }}
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return  _buildLoadingState(theme);
  }

  Widget _buildLoadingState(ThemeData theme) {
    if (stopShimmer) {
      return Center(
        child: Text( "No conversations yet",
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
  return Shimmer.fromColors(
    baseColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
    highlightColor: theme.colorScheme.surface,
    child: ListView.builder(
      itemCount: 10,
      physics: const NeverScrollableScrollPhysics(), 
      itemBuilder: (context, index) => _buildShimmerChatTile(theme),
    ),
  );
}

Widget _buildShimmerChatTile(ThemeData theme) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name Placeholder
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                // Message Placeholder
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Date Placeholder
          Container(
            width: 40,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    ),
  );
}
}