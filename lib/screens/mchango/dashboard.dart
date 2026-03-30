
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/cubit/mchango_cubit.dart';
import 'package:messaging/screens/mchango/campaign_dashboard.dart';
import 'package:messaging/screens/mchango/export.dart';
import 'package:messaging/screens/mchango/mchango_onboarding.dart';
import 'package:messaging/screens/mchango/new_campaign.dart';
import 'package:messaging/screens/mchango/widgets/beta_badge.dart';
import 'package:messaging/screens/mchango/widgets/contribution_tile.dart';
import 'package:messaging/screens/mchango/widgets/mchango_tile.dart';
import 'package:messaging/services/ads/reward_ad_service.dart';
import 'package:messaging/services/mchango_service.dart';



class MchangoDashboardWrapper extends StatelessWidget {
  final String threadId;
  const MchangoDashboardWrapper({super.key, required this.threadId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
          create: (_) => MchangoCubit(threadId),
          child: MchangoDashboard(threadId: threadId),
        );
  }
}

class MchangoDashboard extends StatefulWidget {
  final String threadId;
  const MchangoDashboard({super.key, required this.threadId});

  @override
  State<MchangoDashboard> createState() => _MchangoDashboardState();
}


class _MchangoDashboardState extends State<MchangoDashboard> {
  @override
void initState() {
  loadAd();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future.delayed(const Duration(seconds: 1));
    bool hasSeenOnboarding = await UserDefaults.hasOnboardedMchango();
    
    if (!hasSeenOnboarding && mounted) {
      _showMchangoOnboarding(context);
    }
  });
  super.initState();
  
}
void loadAd(){
  final adService = RewardedAdService();
  adService.loadAd();
}
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mchango'),
            SizedBox(width: 6),
            BetaBadge()
          ],
        ),
        centerTitle: false,
        actions: [
          BlocBuilder<MchangoCubit, MchangoState>(
            builder: (context, state) {
              if (state is! MchangoLoaded || state.activeCampaign == null) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'stop') {
                    final confirm = await _confirmStop(context);
                    if (confirm == true && context.mounted) {
                      context.read<MchangoCubit>().stopCampaign();
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'stop',
                    child: Row(
                      children: [
                        Icon(Icons.stop_circle_outlined, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Stop Campaign',
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<MchangoCubit, MchangoState>(
        listener: (context, state) {
          if (state is MchangoError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is MchangoLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is MchangoLoaded) {
            return _MchangoLoadedView(state: state, threadId: widget.threadId);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: BlocBuilder<MchangoCubit, MchangoState>(
        builder: (context, state) {
          final hasActive = state is MchangoLoaded && state.activeCampaign != null;
          final isDemoMode = state is MchangoLoaded && state.isDemoMode;
          if(isDemoMode && hasActive){
            return FloatingActionButton.extended(
                  onPressed: () {
                    context.read<MchangoCubit>().simulateContribution();
                    
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Mock Add'),
                );
          }
          
          if (hasActive){
            return FloatingActionButton(
                  onPressed: () {
                   //Edit
                  },
                  child: const Icon(Icons.edit),
                );
          }
          return FloatingActionButton.extended(
            onPressed: () => _showNewCampaignSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('New Campaign'),
          );
        },
      ),
      
    );
    
  }
    void _showMchangoOnboarding(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false, // Force them to engage with the "Get Started"
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return const MchangoOnboarding();
    },
  );
}

  Future<bool?> _confirmStop(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Stop Campaign?'),
          content: const Text(
              'This will end the campaign. You can still view its report but no new contributions will be tracked.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Stop'),
            ),
          ],
        ),
      );

  void _showNewCampaignSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<MchangoCubit>(),
        child: const NewCampaignSheet(),
      ),
    );
  }
}
class _MchangoLoadedView extends StatelessWidget {
  final MchangoLoaded state;
  final String threadId;
  const _MchangoLoadedView({required this.state, required this.threadId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (state.activeCampaign == null && state.pastCampaigns.isEmpty) {
      return _EmptyState();
    }

    return CustomScrollView(
      slivers: [
        // ── Active Campaign Dashboard ──────────────────────────
        if (state.activeCampaign != null)
          SliverToBoxAdapter(
            child: CampaignDashboard(campaign: state.activeCampaign!),
          ),

        // ── Contributions Header ───────────────────────────────
        if (state.activeCampaign != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Contributions',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                          
                
                  TextButton.icon(
                    onPressed: () => _handleExport(context),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Export PDF'),
                  ),
                 
                ],
              ),
            ),
          ),

        // ── Contributions List ─────────────────────────────────
        if (state.contributions.isEmpty && state.activeCampaign != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  Text('No contributions yet',
                      style: TextStyle(color: theme.colorScheme.outline)),
                  const SizedBox(height: 4),
                  Text('Received M-Pesa payments will appear here',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),

        SliverList.builder(
          itemCount: state.contributions.length,
          itemBuilder: (context, index) {
            final c = state.contributions[index];
            return ContributionTile(contribution: c, index: index);
          },
        ),

        // ── Past Campaigns ─────────────────────────────────────
        if (state.pastCampaigns.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
              child: Text('Past Campaigns',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          SliverList.builder(
            itemCount: state.pastCampaigns.length,
            itemBuilder: (_, i) =>
                PastCampaignTile(campaign: state.pastCampaigns[i]),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _handleExport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<MchangoCubit>(),
        child: ExportSheet(
          campaign: state.activeCampaign!,
          contributions: state.contributions,
        ),
      ),
    );
  }
  
}
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.savings_outlined,
                size: 72, color: theme.colorScheme.primaryContainer),
            const SizedBox(height: 20),
            Text('No Campaigns Yet',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Start a Mchango campaign to automatically track received M-Pesa contributions from now',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: theme.colorScheme.outline, height: 1.5),
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => BlocProvider.value(
                  value: context.read<MchangoCubit>(),
                  child: const NewCampaignSheet(),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Start First Campaign'),
            ),
          ],
        ),
      ),
    );
  }

}
