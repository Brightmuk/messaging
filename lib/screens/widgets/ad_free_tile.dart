import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:messaging/cubit/payment_cubit.dart';
import 'package:messaging/screens/no_ads_purchase_sheet.dart';

class AdFreeTile extends StatelessWidget {
  const AdFreeTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<PaymentCubit, PaymentState>(
      builder: (context, state) {
        // 1. Check the state to see if the user is already Ad-Free
        // This ensures the banner disappears immediately after a successful purchase
        bool isNoAds = context.read<PaymentCubit>().isNoAds;
        if (isNoAds) {
          return const SizedBox.shrink();
        }
        String price = context.read<PaymentCubit>().price;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700.withAlpha(15), Colors.blue.shade900.withAlpha(15)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  Icons.star,
                  size: 100, 
                  color: theme.colorScheme.onSurface.withAlpha(10)
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.block),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Go Ad-Free Forever!",
                            style: TextStyle(
                            
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withAlpha(100),
                                fontSize: 13,
                              ),
                              children:  [
                                const TextSpan(text: "One-time payment of only "),
                               
                               TextSpan(
                                  text: price,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 5,
                      ),
                      onPressed: () {showModalBottomSheet(
                          context: context,
                          isScrollControlled: true, // Allows it to go full screen
                          backgroundColor: Colors.transparent, // We use our own decoration
                          builder: (context) => const NoAdsPurchaseSheet(),
                        );},
                      child: const Text("GET"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}