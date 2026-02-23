import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/payment_cubit.dart';
import 'package:messaging/services/purchase_service.dart';

class AdFreeTile extends StatelessWidget {
  const AdFreeTile({super.key});

  @override
  Widget build(BuildContext context) {
    bool isNoAds = context.read<PaymentCubit>().isNoAds;
    if (isNoAds) {
      return const SizedBox.shrink();
    }
    return BlocBuilder<PaymentCubit, PaymentState>(
      builder: (context, state) {
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
              // Subtle background decoration
              Positioned(
                right: -20,
                top: -20,
                child: Icon(Icons.star,
                    size: 100, color: Colors.white.withOpacity(0.1)),
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
                                    color: Colors
                                        .white, // Pure white to make it brighter
                                    fontSize:
                                        14, // Slightly larger for emphasis
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
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 5,
                      ),
                      onPressed: () async {
                       context.read<PaymentCubit>().startPurchase();
                      },
                      child:  (state is PaymentProcessing)? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator())): const Text( "GET"),
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
