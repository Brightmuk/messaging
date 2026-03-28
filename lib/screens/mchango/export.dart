
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/payment_cubit.dart';
import 'package:messaging/models/mchango_campaign.dart';
import 'package:messaging/services/pdf_exporter.dart';

class ExportSheet extends StatefulWidget {
  final Campaign campaign;
  final List<Contribution> contributions;
  const ExportSheet(
      {required this.campaign, required this.contributions});

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium =
        context.read<PaymentCubit>().isNoAds;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Icon(Icons.picture_as_pdf_outlined,
              size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Export Report',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '${widget.contributions.length} contributions · Ksh ${widget.campaign.totalCollected.toStringAsFixed(0)}',
            style: TextStyle(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 24),

          if (isPremium) ...[
            // Premium — export directly
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGenerating
                    ? null
                    : () => _export(watermark: false),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_outlined),
                label: Text(
                    _isGenerating ? 'Generating...' : 'Export & Share'),
              ),
            ),
          ] else ...[
            // Free — two options
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGenerating ? null : _watchAdForCleanExport,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Watch Ad — Remove Watermark'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isGenerating
                    ? null
                    : () => _showInterstitialThenExport(),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Export with Watermark'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Watch an ad to remove the watermark from your PDF',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _watchAdForCleanExport() async {
    // Show reward ad then export without watermark
    // Wire your RewardedAd logic here
    Navigator.pop(context);
    await _export(watermark: false);
  }

  Future<void> _showInterstitialThenExport() async {
    // Show interstitial then export with watermark
    // Wire your InterstitialAd logic here
    Navigator.pop(context);
    await _export(watermark: true);
  }

  Future<void> _export({required bool watermark}) async {
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await MchangoPdfExporter.generate(
        campaign: widget.campaign,
        contributions: widget.contributions,
        watermark: watermark,
      );
      await MchangoPdfExporter.share(
          pdfBytes, widget.campaign.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate PDF')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}