
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/mchango_cubit.dart';
import 'package:messaging/models/mchango_campaign.dart';
import 'package:messaging/screens/mchango/campaign_details.dart';

class PastCampaignTile extends StatelessWidget {
  final Campaign campaign;
  const PastCampaignTile({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.savings_outlined,
            color: theme.colorScheme.outline, size: 20),
      ),
      title: Text(campaign.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${campaign.contributorCount} contributors · Ksh ${campaign.totalCollected.toStringAsFixed(0)}',
        style:
            TextStyle(fontSize: 12, color: theme.colorScheme.outline),
      ),
      trailing: Icon(Icons.chevron_right,
          color: theme.colorScheme.outline),
      onTap: () {
        // Navigate to past campaign detail
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<MchangoCubit>(),
              child: PastCampaignDetail(campaign: campaign),
            ),
          ),
        );
      },
    );
  }
}