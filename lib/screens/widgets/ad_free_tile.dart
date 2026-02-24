import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/payment_cubit.dart';

class AdFreeTile extends StatelessWidget {
  const AdFreeTile({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentCubit, PaymentState>(
      builder: (context, state) {
        // 1. Check the state to see if the user is already Ad-Free
        // This ensures the banner disappears immediately after a successful purchase
        bool isNoAds = context.read<PaymentCubit>().isNoAds;
        if (isNoAds) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  Icons.star,
                  size: 100, 
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.block, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Go Ad-Free Forever!",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                              children: const [
                                TextSpan(text: "One-time payment of only "),
                                TextSpan(
                                  text: "Ksh.500 ",
                                  style: TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.white60,
                                    fontSize: 14,
                                  ),
                                ),
                                TextSpan(
                                  text: " Ksh.360",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
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
                      onPressed: (state is PaymentProcessing) 
                          ? null // Disable button while processing
                          : () => context.read<PaymentCubit>().startPurchase(),
                      child: (state is PaymentProcessing)
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("GET"),
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