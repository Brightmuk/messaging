import 'dart:async';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:messaging/services/mask_service.dart';

class PrivacyShieldOverlay extends StatefulWidget {
  const PrivacyShieldOverlay({Key? key}) : super(key: key);

  @override
  State<PrivacyShieldOverlay> createState() => _PrivacyShieldOverlayState();
}

class _PrivacyShieldOverlayState extends State<PrivacyShieldOverlay> {

  String address = "Privacy Shield";
  String message = "Processing...";
  
  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (mounted) {
        setState(() {
          address = data['address'] ?? "Private Message";
          message = data['maskedText'] ?? "Checked balance";
        });
      }
    });
    
    // Auto-close after 10s
    Timer(const Duration(seconds: 10), () {
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
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF212121) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isDarkMode ? Colors.white10 : Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildIdentityAvatar(address, theme),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    address,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.1,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _buildShieldBadge(),
                              ],
                            ),
                            Text(
                              "Privacy Shield • Active",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorMap(address),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Pushed to the far right
                      IconButton(
                        onPressed: () => FlutterOverlayWindow.closeOverlay(),
                        icon: const Icon(Icons.close_rounded, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(), 
                        visualDensity: VisualDensity.compact,
                        color: isDarkMode ? Colors.white54 : Colors.black45,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 12),
                    child: Divider(height: 1, thickness: 0.5),
                  ),

                  // 3. Message Body
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      MaskService.maskAfterBalance(message, address).message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  
                
                  // 4. Action Buttons (Open and Dismiss)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      
                      
                      TextButton(
                         onPressed: () async {
                              try {
                                
                                const intent = AndroidIntent(
                                  action: 'android.intent.action.MAIN',
                                  package: 'com.brimukon.messaging',
                                  componentName: 'com.brimukon.messaging.MainActivity',
                                  flags: [Flag.FLAG_ACTIVITY_NEW_TASK, Flag.FLAG_ACTIVITY_REORDER_TO_FRONT],
                                );

                                await intent.launch();
                                await FlutterOverlayWindow.closeOverlay();
                              } catch (e) {
                                debugPrint("Could not launch app via Intent: $e");
                                await FlutterOverlayWindow.closeOverlay();
                              }
                            },
                        child:  Text(
                          "OPEN",
                          style: TextStyle(
                            color: colorMap(address),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => FlutterOverlayWindow.closeOverlay(),
                        child: Text(
                          "DISMISS",
                          style: TextStyle(
                            color: isDarkMode ? Colors.white54 : Colors.black54,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Color colorMap(String label) {
    if (label.toUpperCase().contains("MPESA")) {
      return Colors.green;
    } else if (label.toUpperCase().contains("AIRTEL")) {
      return Colors.red;
    } else {
      return Colors.blue;
    }
  }

  Widget _buildIdentityAvatar(String label, ThemeData theme) {
   
    return CircleAvatar(
      radius: 22,
      backgroundColor: colorMap(address),
      child: Text(
        label.isNotEmpty ? label[0].toUpperCase() : "P",
        style: const TextStyle(
          color:  Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildShieldBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorMap(address).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorMap(address).withOpacity(0.2)),
      ),
      child:  Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_rounded, color: colorMap(address), size: 10),
          const SizedBox(width: 4),
          Text(
            "PROTECTED",
            style: TextStyle(
              color: colorMap(address), 
              fontSize: 8, 
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}