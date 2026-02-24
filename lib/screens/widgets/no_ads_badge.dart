import 'package:flutter/material.dart';
import 'package:messaging/cubit/payment_cubit.dart';
import 'package:provider/provider.dart';

class NoAdsBadge extends StatelessWidget {
  const NoAdsBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // Optimized: Only rebuilds if isNoAds changes
    final isPremium = context.select((PaymentCubit cubit) => cubit.isNoAds);

    if (!isPremium) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
     padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A148C),
                Color(0xFF7B1FA2),],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.star, size: 14, color: Colors.white),
        ],
      ),
    );
  }
}