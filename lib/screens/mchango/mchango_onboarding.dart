import 'package:flutter/material.dart';
import 'package:messaging/core/user_defaults.dart';

class MchangoOnboarding extends StatelessWidget {
  const MchangoOnboarding({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon & Title
          CircleAvatar(
            radius: 32,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.analytics_outlined,
                size: 32, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            "Smart Mchango Tracker",
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
                  Text(

        "Use this feature to track M-PESA contributions for your next Mchango campaign.",

        textAlign: TextAlign.center,

        style: theme.textTheme.bodyMedium,

        ),
         const SizedBox(height: 12),
          // Feature Description
          Column(
            children: [
              _buildFeatureItem(
                context,
                icon: Icons.track_changes_rounded,
                title: "Automated Tracking",
                description:
                    "Once active, M-Ficha automatically detects (Received) M-PESA transaction messages as they arrive.",
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                icon: Icons.calculate_outlined,
                title: "Real-time Totals",
                description:
                    "Each contribution(Received transaction) is populated to your ongoing campaign.",
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                icon: Icons.ios_share_rounded,
                title: "Shareable Reports",
                description:
                    "Easily export the final results as a PDF, and share with the contributors and stakeholders.",
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Privacy Affirmation Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "This feature is completely offline. All data is stored on your device. ",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                // Save flag so it doesn't show again
                await UserDefaults.setHasOnboardedMchango();
                Navigator.pop(context);
              },
              child: const Text("Get Started"),
            ),
          ),

          const SizedBox(height: 24),

          // Footer Disclaimer
          Text(
            "Disclaimer: Accuracy is our priority, but automated systems can occasionally misinterpret data. Please cross-check all totals and contributor names before finalizing your records.",
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context,
      {required IconData icon,
      required String title,
      required String description}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4, // Better readability
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
