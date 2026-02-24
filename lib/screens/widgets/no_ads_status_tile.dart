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
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4A148C), // Material Purple 900
                Color(0xFF7B1FA2), // Material Purple 700
              ],
            ),
          ),
          child: Row(
            children: [
              // Icon with a soft white-glow background
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
                ),
                child: const Icon(
        Icons.workspace_premium_rounded, 
        color: Colors.white, 
        size: 28
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "M-Ficha Premium",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 17,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            "Lifetime ad-free experience active\n",
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
                ),
              ),
              const Icon(
                Icons.check_circle_rounded, 
                color: Colors.white70, 
                size: 20
              ),
            ],
          ),
        );
      },
    );
  }
}