
import 'package:flutter/material.dart';
import 'package:messaging/models/mchango_campaign.dart';



class CampaignDashboard extends StatelessWidget {
  final Campaign campaign;
  const CampaignDashboard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Campaign name + active badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('Active',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Total amount
            Text(
              'Total Collected',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ksh ${_formatAmount(campaign.totalCollected)}',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),

            // Progress bar (only if target set)
            if (campaign.targetAmount != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Target: Ksh ${_formatAmount(campaign.targetAmount!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    '${(campaign.progress * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: campaign.progress,
                  minHeight: 8,
                  backgroundColor:
                      colorScheme.onPrimaryContainer.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    campaign.progress >= 1.0 ? Colors.green : colorScheme.primary,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Stats row
            Row(
              children: [
                _StatChip(
                  icon: Icons.people_outline,
                  label: '${campaign.contributorCount} Contributors',
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.calendar_today_outlined,
                  label: _formatDate(campaign.startDate),
                  color: colorScheme.onPrimaryContainer,
                ),
                if (campaign.endDate != null) ...[
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.timer_outlined,
                    label: 'Ends ${_formatDate(campaign.endDate!)}',
                    color: colorScheme.onPrimaryContainer,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}