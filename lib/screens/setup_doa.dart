import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/screens/widgets/privacy_overlay.dart';

class OverlayPermissionScreen extends StatefulWidget{
  const OverlayPermissionScreen({super.key});

  @override
  State<OverlayPermissionScreen> createState() => _OverlayPermissionScreenState();
}

class _OverlayPermissionScreenState extends State<OverlayPermissionScreen>  with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
    @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifyPermissionStatus();
    }
  }
  bool _isWaitingForOverlayPermission = false;
  Future<void> _verifyPermissionStatus() async {
    if(!_isWaitingForOverlayPermission) return ;
    bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (isGranted) {
      await UserDefaults.setShowOverlay(true);
      _isWaitingForOverlayPermission = false;
      Navigator.pop(context);
    } else {
      _isWaitingForOverlayPermission = false;
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wrap content height
          children: [
            // Handle bar for the bottom sheet
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Icon and Title
            Icon(Icons.layers_outlined, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              "Enable Smart Overlays",
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "See message previews without opening the app. To enable this, we need permission to 'Display over other apps'.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
              const SizedBox(height: 12),
            const OverlayWidget(address: "MPESA", message: "UBM487RO6P Confirmed. You have received Ksh1,500.00 from Kasongo Yeye 0700000000 on 9/3/26 at 9:15 AM. New M-PESA balance is Ksh....",),
            const SizedBox(height: 24),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(context); // Close sheet first
                  await FlutterOverlayWindow.requestPermission();
                  _isWaitingForOverlayPermission = true;
                  

                },
                child: const Text("Grant Permission"),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  // Optional: Save a flag to not ask again for a while
                  UserDefaults.setDismissedShowOverlayPrompt();
                  Navigator.pop(context);
                },
                child: const Text("Maybe Later"),
              ),
            ),
          ],
        ),
      );
  }
}

void showOverlayBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
        return const OverlayPermissionScreen();
    },
  );
}