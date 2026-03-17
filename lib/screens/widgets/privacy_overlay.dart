import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:messaging/services/redact_service.dart';

class PrivacyShieldOverlay extends StatefulWidget {
  const PrivacyShieldOverlay({Key? key}) : super(key: key);

  @override
  State<PrivacyShieldOverlay> createState() => _PrivacyShieldOverlayState();
}

class _PrivacyShieldOverlayState extends State<PrivacyShieldOverlay> {
  String address = "Shield Active";
  String message = "Processing privacy shield...";
  
  @override
  void initState() {
    super.initState();
    
    FlutterOverlayWindow.overlayListener.listen((data) {
      setState(() {
        address = data['address'] ?? "Private Message";
        message = data['redactedText'] ?? "Checked balance";
      });
    });
    
    Future.delayed(const Duration(seconds: 10), () {
      
      if (mounted) FlutterOverlayWindow.closeOverlay();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(

          color: isDarkMode ? const Color(0xFF1D1B20) : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05), 
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.5 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Security Icon with a soft background tint
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        address,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Small privacy badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "REDACTED",
                          style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Spacer(),
                      IconButton(onPressed: (){
                        FlutterOverlayWindow.closeOverlay();
                      }, icon: Icon(Icons.clear_outlined,size: 16,))
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    RedactService.redactAfterBalance(message, address),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                     
                      TextButton(onPressed: (){
                         FlutterOverlayWindow.closeOverlay();
                      }, child: const Text('Done'))
                    ],
                  )
        
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}