
import 'package:flutter/material.dart';
import 'package:messaging/models/mchango_campaign.dart';

class ContributionTile extends StatelessWidget {
  final Contribution contribution;
  final int index;
  const ContributionTile({required this.contribution, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date =
        DateTime.fromMillisecondsSinceEpoch(contribution.date);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        backgroundColor:
            theme.colorScheme.primaryContainer,
        child: Text(
          _initials(contribution.senderName ?? contribution.senderPhone),
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(
        contribution.senderName ?? contribution.senderPhone,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${date.day}/${date.month}/${date.year} · ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
        style: TextStyle(
            fontSize: 12, color: theme.colorScheme.outline),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Text(
          'Ksh ${contribution.amount.toStringAsFixed(0)}',
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

 String _initials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';

  final parts = trimmed.split(' ')
      .where((p) => p.isNotEmpty) // filter out multiple spaces
      .toList();

  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  return parts[0][0].toUpperCase();
}
}