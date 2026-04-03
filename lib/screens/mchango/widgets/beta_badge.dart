
import 'package:flutter/material.dart';

class BetaBadge extends StatelessWidget {
  const BetaBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.4),
          width: 0.8,
        ),
      ),
      child: Text(
        'BETA',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}