import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/payment_cubit.dart';
import 'package:url_launcher/url_launcher.dart';

class NoAdsPurchaseSheet extends StatelessWidget {
  const NoAdsPurchaseSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return BlocConsumer<PaymentCubit, PaymentState>(
      listener: (context, state) {
        if (state is PaymentSuccess) Navigator.pop(context);
      },
      builder: (context, state) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 1. Sophisticated Header
                _buildPremiumHeader(context, isDarkMode),
            
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        _buildFeatureRow(Icons.auto_awesome, "Ad-free experience", "Browse your messages without interruptions."),
                        _buildFeatureRow(Icons.speed, "Streamlined Interface & Performance", "A faster, distraction-free experience with zero external ad-resource loading."),
                        _buildFeatureRow(Icons.verified_user_outlined, "Priority Updates", "Get the latest privacy features before anyone else."),
                        
                        const Spacer(),
            
                        // 2. Pricing Section
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "SPECIAL INTRODUCTORY OFFER",
                                style: TextStyle(
                                  color: Colors.amber.shade800,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text("Ksh 500",
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        color: theme.colorScheme.onSurface.withOpacity(0.4))),
                                const SizedBox(width: 12),
                                Text("Ksh 360",
                                    style: theme.textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: theme.colorScheme.onSurface)),
                              ],
                            ),
                            Text("One-time payment. Lifetime access.",
                                style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
            
                        // 3. High-End CTA
                        _buildMainButton(context, state),
                        
                        const SizedBox(height: 20),
            
                        // 4. Footer Links
                        _buildFooter(context),
                        const SizedBox(height: 15),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumHeader(BuildContext context, bool isDarkMode) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode 
                  ? [const Color(0xFF1A237E), const Color(0xFF000000)]
                  : [const Color(0xFF283593), const Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.workspace_premium, size: 48, color: Colors.amberAccent),
              const SizedBox(height: 16),
              const Text(
                "M-FICHA PRO",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              Text(
                "Elevate your messaging privacy",
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              ),
            ],
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade400, size: 28),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton(BuildContext context, PaymentState state) {
    final bool isProcessing = state is PaymentProcessing;
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: isProcessing ? null : () => context.read<PaymentCubit>().startPurchase(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A237E), // Deep Indigo
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: isProcessing
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text("ACTIVATE PRO ACCESS", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: () => context.read<PaymentCubit>().restorePurchase(),
          child: Text("Restore Previous Purchase", style: TextStyle(color: Colors.blue.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(color: Colors.grey, fontSize: 11),
              children: [
                const TextSpan(text: "Terms apply. By upgrading, you agree to our "),
                TextSpan(
                  text: "Terms of Service",
                  style: const TextStyle(decoration: TextDecoration.underline),
                  recognizer: TapGestureRecognizer()..onTap = () => _launchUrl('https://brimukon.com/m-ficha/terms'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}