import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/mchango_cubit.dart';
import 'package:messaging/screens/mchango/dashboard.dart';

class MchangoActiveBanner extends StatelessWidget {
  final String threadId;
  const MchangoActiveBanner({super.key, required this.threadId});

  @override
  Widget build(BuildContext context) {
    return _BannerWidget(threadId);
  }
}

class _BannerWidget extends StatefulWidget {
  final String threadId;
  const _BannerWidget(this.threadId);

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      lowerBound: 0.7,
      upperBound: 1.0,
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (context) => MchangoCubit(widget.threadId),
      child: Builder(builder: (context) {
        return SizedBox(
          height: 60,
          width: MediaQuery.of(context).size.width,
          child: BlocBuilder<MchangoCubit, MchangoState>(
            builder: (context, state) {

              if (state is! MchangoLoaded || state.activeCampaign == null) {
                return const SizedBox.shrink();
              }

              final campaign = state.activeCampaign!;

              return InkWell(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) =>
                          MchangoDashboardWrapper(threadId: widget.threadId, cubit: context.read<MchangoCubit>())));
                },
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    border: Border(
                      bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Pulse Indicator
                      _buildPulseIndicator(),
                      const SizedBox(width: 12),

                      // Campaign Info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Ongoing Mchango Campaign",
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Tracking contributions in ${campaign.name}",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Stats Chips
                      _buildStatChip(context, "${campaign.contributorCount}",
                          Icons.people_alt_outlined),
                      const SizedBox(width: 8),
                      _buildStatChip(
                          context,
                          "Ksh ${campaign.totalCollected.toStringAsFixed(0)}",
                          Icons.payments_outlined,
                          isPrimary: true),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildPulseIndicator() {
    return FadeTransition(
      opacity: _pulseController,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.blueAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.blue, blurRadius: 4, spreadRadius: 1)
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, String text, IconData icon,
      {bool isPrimary = false}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 12,
              color: isPrimary
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isPrimary
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
