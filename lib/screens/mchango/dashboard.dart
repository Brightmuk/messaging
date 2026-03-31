
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/cubit/mchango_cubit.dart';
import 'package:messaging/models/mchango_campaign.dart';
import 'package:messaging/screens/mchango/campaign_dashboard.dart';
import 'package:messaging/screens/mchango/export.dart';
import 'package:messaging/screens/mchango/mchango_onboarding.dart';
import 'package:messaging/screens/mchango/new_campaign.dart';
import 'package:messaging/screens/mchango/widgets/beta_badge.dart';
import 'package:messaging/screens/mchango/widgets/contribution_tile.dart';
import 'package:messaging/screens/mchango/widgets/mchango_tile.dart';
import 'package:messaging/services/ads/reward_ad_service.dart';




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
                    _showNewCampaignSheet(context, toEdit: state.activeCampaign);
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

  void _showNewCampaignSheet(BuildContext context, {Campaign? toEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<MchangoCubit>(),
        child: NewCampaignSheet(toEdit: toEdit),
      ),
    );
  }
}
class _MchangoLoadedView extends StatefulWidget {
  final MchangoLoaded state;
  final String threadId;
  const _MchangoLoadedView({required this.state, required this.threadId});

  @override
  State<_MchangoLoadedView> createState() => _MchangoLoadedViewState();
}

class _MchangoLoadedViewState extends State<_MchangoLoadedView> {
  final Set<int> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  Future<void> _deleteSelected(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Contributions?'),
        content: Text(
          'Remove ${_selectedIds.length} selected '
          '${_selectedIds.length == 1 ? 'contribution' : 'contributions'}? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      for (final id in _selectedIds) {
        await context.read<MchangoCubit>().deleteContribution(id);
      }
      _clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contributions = widget.state.contributions;

    return CustomScrollView(
      slivers: [
        // ── Selection mode app bar ───────────────────────────
        if (_isSelectionMode)
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: theme.colorScheme.primaryContainer,
            title: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelection,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_selectedIds.length} selected',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              // Select all
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    final allIds = contributions
                        .where((c) => c.id != null)
                        .map((c) => c.id!)
                        .toSet();
                    if (_selectedIds.length == allIds.length) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds.addAll(allIds);
                    }
                  });
                },
                icon: Icon(
                  _selectedIds.length == contributions.length
                      ? Icons.deselect
                      : Icons.select_all,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                label: Text(
                  _selectedIds.length == contributions.length
                      ? 'Deselect All'
                      : 'Select All',
                  style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
              // Delete selected
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete selected',
                onPressed: () => _deleteSelected(context),
              ),
            ],
          ),

        // ── Active Campaign Dashboard ────────────────────────
        if (widget.state.activeCampaign != null && !_isSelectionMode)
          SliverToBoxAdapter(
            child:
                CampaignDashboard(campaign: widget.state.activeCampaign!),
          ),

        // ── Contributions header ─────────────────────────────
        if (widget.state.activeCampaign != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Contributions',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  if (!_isSelectionMode)
                    TextButton.icon(
                      onPressed: () => _handleExport(context),
                      icon: const Icon(Icons.picture_as_pdf_outlined,
                          size: 18),
                      label: const Text('Export PDF'),
                    ),
                ],
              ),
            ),
          ),

        // ── Empty state ──────────────────────────────────────
        if (contributions.isEmpty && widget.state.activeCampaign != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  Text('No contributions yet',
                      style:
                          TextStyle(color: theme.colorScheme.outline)),
                  const SizedBox(height: 4),
                  Text(
                    'Received M-Pesa payments will appear here',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

        // ── Contributions list ───────────────────────────────
        SliverList.builder(
          itemCount: contributions.length,
          itemBuilder: (context, index) {
            final c = contributions[index];
            final isSelected = c.id != null && _selectedIds.contains(c.id);

            return GestureDetector(
              onLongPress: () {
                if (c.id != null) _toggleSelection(c.id!);
              },
              onTap: () {
                if (_isSelectionMode && c.id != null) {
                  _toggleSelection(c.id!);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: isSelected
                    ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                    : Colors.transparent,
                child: Row(
                  children: [
                    // Checkbox appears in selection mode
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: _isSelectionMode
                          ? Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Checkbox(
                                value: isSelected,
                                onChanged: c.id != null
                                    ? (_) => _toggleSelection(c.id!)
                                    : null,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: ContributionTile(
                        contribution: c,
                        index: index,
                        // Disable dismissible in selection mode
                        allowDismiss: !_isSelectionMode,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // ── Past Campaigns ───────────────────────────────────
        if (widget.state.pastCampaigns.isNotEmpty && !_isSelectionMode) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
              child: Text('Past Campaigns',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          SliverList.builder(
            itemCount: widget.state.pastCampaigns.length,
            itemBuilder: (_, i) => PastCampaignTile(
                campaign: widget.state.pastCampaigns[i]),
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
          campaign: widget.state.activeCampaign!,
          contributions: widget.state.contributions,
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
