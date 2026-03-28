import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/mchango_cubit.dart';
import 'package:messaging/models/mchango_campaign.dart';
import 'package:messaging/screens/mchango/export.dart';
import 'package:messaging/screens/mchango/widgets/contribution_tile.dart';
import 'package:messaging/services/mchango_service.dart';

class PastCampaignDetail extends StatefulWidget {
  final Campaign campaign;
  const PastCampaignDetail({required this.campaign});

  @override
  State<PastCampaignDetail> createState() => _PastCampaignDetailState();
}

class _PastCampaignDetailState extends State<PastCampaignDetail> {
  List<Contribution> _contributions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContributions();
  }

  Future<void> _loadContributions() async {
    final contributions = await MchangoService()
        .getContributions(widget.campaign.id!);
    if (mounted) {
      setState(() {
        _contributions = contributions;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final campaign = widget.campaign;

    return Scaffold(
      appBar: AppBar(
        title: Text(campaign.name),
        actions: [
           TextButton.icon(
                    onPressed: () => _handleExport(context),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Export PDF'),
                  ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Summary card ─────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ended badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Ended',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Total
                        Text('Total Collected',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline)),
                        const SizedBox(height: 4),
                        Text(
                          'Ksh ${campaign.totalCollected.toStringAsFixed(0)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold),
                        ),

                        // Progress bar if target was set
                        if (campaign.targetAmount != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Target: Ksh ${campaign.targetAmount!.toStringAsFixed(0)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline),
                              ),
                              Text(
                                '${(campaign.progress * 100).toStringAsFixed(0)}%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: campaign.progress,
                              minHeight: 8,
                              backgroundColor:
                                  theme.colorScheme.outline.withOpacity(0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                campaign.progress >= 1.0
                                    ? Colors.green
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Date range + contributor count
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _StatChip(
                              icon: Icons.people_outline,
                              label:
                                  '${campaign.contributorCount} Contributors',
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            _StatChip(
                              icon: Icons.calendar_today_outlined,
                              label:
                                  'Started ${_formatDate(campaign.startDate)}',
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            if (campaign.endDate != null)
                              _StatChip(
                                icon: Icons.event_available_outlined,
                                label:
                                    'Ended ${_formatDate(campaign.endDate!)}',
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Contributions header ──────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          'Contributions ',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          // width: 28,
                          height: 28,
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(child: Text("${_contributions.length}",style: TextStyle(color: theme.colorScheme.onPrimaryContainer,fontWeight: FontWeight.bold),))
                          
                        )
                      ],
                    ),
                  ),
                ),

                // ── Empty contributions ───────────────────────────
                if (_contributions.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 40, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          Text('No contributions recorded',
                              style: TextStyle(
                                  color: theme.colorScheme.outline)),
                        ],
                      ),
                    ),
                  ),

                // ── Contributions list ────────────────────────────
                SliverList.builder(
                  itemCount: _contributions.length,
                  itemBuilder: (_, i) => ContributionTile(
                    contribution: _contributions[i],
                    index: i,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }

  void _handleExport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<MchangoCubit>(),
        child: ExportSheet(
          campaign: widget.campaign,
          contributions: _contributions,
        ),
      ),
    );
  }

  String _formatDate(int timestamp) {
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${d.day}/${d.month}/${d.year}';
  }
}
// Top level — not nested inside any class
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}