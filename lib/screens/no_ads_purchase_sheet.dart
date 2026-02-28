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

    return BlocConsumer<PaymentCubit, PaymentState>(
      listener: (context, state) {
        if(state is PaymentSuccess){
          Navigator.pop(context);
        }
      },
      builder: (context, state) {
        return Container(
          height:
              MediaQuery.of(context).size.height * 0.85, // Almost full screen
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 1. The Header with your signature Gradient
              Stack(
                children: [
                 
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade700, Colors.blue.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child:  const Column(
                      children: [
                         Icon(Icons.star, size: 60, color: Colors.orangeAccent),
                         SizedBox(height: 12),
                         Text(
                          "Ad-Free Forever",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text('One time purchase',style: TextStyle(color: Colors.white),)
                      ],
                    ),
                  ),
                   Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  Icons.star,
                  size: 150, 
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
               Positioned(
                right: -10,
                bottom: 10,
                child: Icon(
                  Icons.star,
                  size: 50, 
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
                  
                  // THE CLOSE BUTTON
                  Positioned(
                    top: 12,
                    left: 12,
                    child: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),

              // 2. The Features/Information
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      _buildFeatureRow(Icons.block,
                          "Remove all advertisements permanently."),
                      _buildFeatureRow(Icons.bolt,
                          "Faster performance & cleaner interface."),
                      _buildFeatureRow(
                          Icons.favorite, "Support the developers of M-Ficha."),
                      const Spacer(),

                      // 3. Pricing Section
                       Text("Limited Time Offer",
                          style: theme.textTheme.labelMedium!.copyWith(color: theme.colorScheme.onSurface.withAlpha(100))),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Ksh 500",
                              style: theme.textTheme.titleMedium?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: theme.colorScheme.onSurface.withAlpha(100)
                                  )),
                          const SizedBox(width: 12),
                          const Text("Ksh 360",
                              style: TextStyle(
                                  fontSize: 32, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 4. CTA Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: (state is PaymentProcessing)?  null: () {
                            context.read<PaymentCubit>().startPurchase();
                        
                          },
                          child: (state is PaymentProcessing) ?  const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ): const Text("UPGRADE NOW",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. Restore Purchase Link
                      TextButton(
                        onPressed: () =>
                            context.read<PaymentCubit>().restorePurchase(),
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodyMedium,
                            children: [
                              const TextSpan(text: "Already purchased? "),
                              TextSpan(
                                text: "Restore",
                                style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey), // Base style
                            children: [
                              const TextSpan(text: "By purchasing this item you have read and agree to our\n "),
                              TextSpan(
                                text: "Terms & Conditions",
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                                // THIS MAKES IT CLICKABLE
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    _launchUrl('https://brimukon.com/terms');
                                  },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: Icon(icon, color: Colors.blue.shade700, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }
}
