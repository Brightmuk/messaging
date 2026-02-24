import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/payment_cubit.dart';

class NoAdsStatusTile extends StatelessWidget {
  const NoAdsStatusTile({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentCubit, PaymentState>(
      builder: (context, state) {
        final isPremium = context.select((PaymentCubit cubit) => cubit.isNoAds);
        if (!isPremium) {
          return const SizedBox.shrink();
        }

        // 2. Return the "Premium Member" status card
        return GestureDetector(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade200, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.verified, color: Colors.amber.shade800),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Premium Member",
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Ad-free experience active",
                        style: TextStyle(
                          color: Colors.amber.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Optional: A 'Manage' label or just a checkmark
                Icon(Icons.check_circle_outline, color: Colors.amber.shade700),
              ],
            ),
          ),
        );
      },
    );
  }
}