import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/payment_cubit.dart';
import 'package:messaging/models/mchango_campaign.dart';
import 'package:messaging/services/ads/reward_ad_service.dart';
import 'package:messaging/services/pdf_exporter.dart';

class ExportSheet extends StatefulWidget {
  final Campaign campaign;
  final List<Contribution> contributions;
  const ExportSheet({super.key, required this.campaign, required this.contributions});

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  bool _isGenerating = false;
  final TapGestureRecognizer _copyRecognizer = TapGestureRecognizer();
  @override
  void dispose() {
    _copyRecognizer.dispose(); // ← prevents memory leak
    super.dispose();
  }
  bool _loadingExportWithAd = false;
  bool _loadingExportWithoutAd = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = context.read<PaymentCubit>().isNoAds;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
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
          Text('Export Report as PDF',
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
                onPressed:
                    _isGenerating ? null : () => _export(watermark: false),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_outlined),
                label: Text(_isGenerating ? 'Generating...' : 'Export & Share'),
              ),
            ),
          ] else ...[
            // Free — two options
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGenerating ? null : _watchAdForCleanExport,
                icon: const Icon(Icons.play_circle_outline),
                label: _loadingExportWithAd? const SizedBox(
                width: 18,
                height: 18,
                child:  CircularProgressIndicator(color: Colors.white,)): const Text('Watch Ad — Remove Watermark'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _isGenerating ? null : () => _justExport(),
                icon: const Icon(Icons.download_outlined),
                label: _loadingExportWithoutAd? const SizedBox(
                  width: 18,
                  height: 18,
                  child:  CircularProgressIndicator()): const Text('Export with Watermark'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          const Text('Or'),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              children: [
                TextSpan(
                  text: 'Copy as a list ',
                  style: TextStyle(
                    color: widget.contributions.isEmpty
                        ? theme.colorScheme.outline
                        : theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    decorationColor: theme.colorScheme.primary,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = widget.contributions.isEmpty ? null : _copyAsText,
                ),
                const TextSpan(
                  text: 'with amounts and total',
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Future<void> _watchAdForCleanExport() async {
    setState(() {
      _loadingExportWithAd = true;
    });
    RewardedAdService().showAd(
      onRewardEarned: (reward) async {
        await Future.delayed(const Duration(seconds: 1)); 
         await _export(watermark: false);
        Navigator.pop(context);
      },
    );

  }

  Future<void> _justExport() async {
      setState(() {
        _loadingExportWithoutAd = true;
      });
    await _export(watermark: true);
    Navigator.pop(context);
  }

  Future<void> _export({required bool watermark}) async {
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await MchangoPdfExporter.generate(
        campaign: widget.campaign,
        contributions: widget.contributions,
        watermark: watermark,
      );
      await MchangoPdfExporter.share(pdfBytes, widget.campaign.name);
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

  Future<void> _copyAsText() async {
    final buffer = StringBuffer();
    buffer.writeln("*${widget.campaign.name} contributions*");
    buffer.writeln();

    double total = 0;
    for (int i = 0; i < widget.contributions.length; i++) {
      final c = widget.contributions[i];
      final name = c.senderName ?? c.senderPhone;
      final amount = c.amount.toStringAsFixed(0);
      buffer.writeln('${i + 1}. $name - Ksh.$amount');
      total += c.amount;
    }
    buffer.writeln();
    buffer.writeln('*Total: Ksh.${total.toStringAsFixed(0)}*');
    buffer.writeln();
    buffer.writeln('📲 Track contributions with M-Ficha');
    buffer.writeln(
        'https://play.google.com/store/apps/details?id=com.brimukon.messaging');

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Copied to clipboard'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
