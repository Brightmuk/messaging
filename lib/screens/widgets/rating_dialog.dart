import 'package:flutter/material.dart';
import 'package:messaging/core/utils/functions.dart';
import 'package:messaging/services/rating_limiter.dart';

void showRateUsDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // Force them to choose an option
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Loving M-Ficha?"),
      content: const Text(
        "You've been using M-Ficha for a while now! Would you mind taking a moment to rate us on the Play Store?",
      ),
      actions: [
         TextButton(
          onPressed: () async {
            await RateLimiter.markAsRated();
            if (context.mounted) Navigator.pop(context);
          },
          child: Text("NEVER", style: TextStyle(color: Colors.grey[600])),
        ),
        TextButton(
          onPressed: () async {
            await RateLimiter.snooze(); 
            if (context.mounted) Navigator.pop(context);
          },
          child: Text("LATER", style: TextStyle(color: Colors.grey[600])),
        ),
        FilledButton(
          onPressed: () async {
            await RateLimiter.markAsRated(); 
            if (context.mounted) {
              Navigator.pop(context);
              openPlayStore();
            }
          },
          child: const Text("RATE NOW"),
        ),
      ],
    ),
  );
}