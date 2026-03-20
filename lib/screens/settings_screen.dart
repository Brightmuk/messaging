import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:messaging/core/events.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/core/utils/functions.dart';
import 'package:messaging/models/sim_card_state.dart';
import 'package:messaging/screens/archived_chats_screen.dart';
import 'package:messaging/screens/widgets/ad_free_tile.dart';
import 'package:messaging/screens/widgets/no_ads_status_tile.dart';
import 'package:messaging/services/notification_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sms_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _isDefaultSmsApp = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDefaultSmsStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDefaultSmsStatus();
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
      setState(() {}); 
    }
  }

  Future<void> _checkDefaultSmsStatus() async {
    final isDefault = await SmsService.isDefaultSmsApp();
    setState(() => _isDefaultSmsApp = isDefault);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.all(16.0), // Outer padding for the cards
                children: [
                  _buildSectionHeader("App"),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerLow, // Subtle M3 background
                    clipBehavior:
                        Clip.antiAlias, // Ensures ink splashes are rounded
                    child: Column(
                      children: [
                        ListTile(
                          leading:  Icon(Icons.messenger_outline, color: theme.colorScheme.primary),
                          title: const Text("Default Messaging App"),
                          subtitle: Text(_isDefaultSmsApp
                              ? "This is the default messaging app"
                              : "Tap to set as default"),
                          trailing: _isDefaultSmsApp
                              ? const Icon(Icons.check_circle_outline, color: Colors.green)
                              : FilledButton(
                                  onPressed: () async {
                                    await SmsService.requestDefaultSmsRole();
                                    await Future.delayed(
                                        const Duration(seconds: 5));
                                    if (mounted) {
                                      setState(() {});
                                      await SmsService.requestDefaultSmsRole();
                                    }
                                  },
                                  child: const Text('Set as Default')),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        FutureBuilder<AppSimCardState>(
                          future: SmsService().getSimState(),
                          builder: (context, sn) {
                            // 1. Extract data safely. 
                            // If it's still loading or has an error, simCardState will be null.
                            final simCardState = sn.data;
                            
                            // 2. Perform safe lookup using ?. and firstOrNull
                            final currentSim = simCardState?.allCards.where((sim) {
                              final slot = int.tryParse(sim.slotIndex);
                              return slot != null && slot == simCardState.defaultCard;
                            }).firstOrNull;
        
                            // 3. Build UI - No loaders, just logic
                            final bool hasValidSim = currentSim != null;
                            final int displaySlot = (int.tryParse(currentSim?.slotIndex ?? "") ?? 0) + 1;
        
                            return ListTile(
                              title: const Text("Default SIM Card"),
                              subtitle: Text(
                                hasValidSim 
                                  ? "SIM $displaySlot (${currentSim.displayName})" 
                                  : "Select default SIM"
                              ),
                              leading:  Icon(Icons.sim_card_outlined, color: theme.colorScheme.primary),
                              trailing: const Icon(Icons.arrow_drop_down),
                              onTap: _showSimPicker,
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                         ListTile(
                            leading:  Icon(Icons.archive_outlined, color: theme.colorScheme.primary),
                            title: const Text("Archived Conversations"),
                            trailing: FutureBuilder<int>(
                              future: SmsService().getArchivedCount(),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                return Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    "$count",
                                    style:  TextStyle(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                            onTap: () async{
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ArchivedChatsScreen()),
                              );
                              if(result!=null){
                                setState(() {});
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24), // Space between cards
        
                  _buildSectionHeader("Preferences"),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        FutureBuilder(
                          future: UserDefaults.getHideStatus(),
                          builder: (context, asyncSnapshot) {
                            return SwitchListTile(
                            
                              title: const Text("Always hide balances"),
                              value: asyncSnapshot.data ?? false, 
                              onChanged: (value) async {
                                await UserDefaults.setHideStatus(value);
                                setState(() {});
                              }
                              );
                          }
                        ),
                        // const Divider(height: 1, indent: 16, endIndent: 16),
                        // FutureBuilder<bool>(
                        //   future: NotificationService.canShowOverlay(),
                        //   builder: (context, asyncSnapshot) {
                        //     return SwitchListTile(
                            
                        //       title: const Text("Payment confirmation shortcuts"),
                        //       subtitle: const Text('Show an overlay to quickly verify payments without opening the app'),
                        //       value: asyncSnapshot.data ?? false, 
                        //       onChanged: (value) async {
                        //         if(!await FlutterOverlayWindow.isPermissionGranted()){
                        //           _isWaitingForOverlayPermission = true;
                        //         }
                        //           await NotificationService.setShowOverlay(value);
                        //           setState(() {});
                        //         }
                        //       );
                        //   }
                        // ),
                       
                      ],
                    ),
                  ),
                   const SizedBox(height: 15),
                  const AdFreeTile(),
                  const NoAdsStatusTile(),
        
        
                  const SizedBox(height: 24), // Space between cards
        
                  _buildSectionHeader("Other"),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildLinkTile(
                          Icons.star_rate,
                          "Rate App",
                          () => openPlayStore(),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildLinkTile(
                          Icons.privacy_tip_outlined,
                          "Privacy Policy",
                          () => _launchUrl('https://brimukon.com/m-ficha/privacy'),
                        ),
                        
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildLinkTile(
                          Icons.help_outline,
                          "Help & Feedback",
                          () => _launchUrl('https://brimukon.com/support'),
                        ),
                        
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // Helper logic methods (LaunchUrl, showSimPicker, etc.) remain exactly as you wrote them
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $urlString')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }


  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          8, 0, 16, 12), // Adjusted for card alignment
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildLinkTile(IconData icon, String title, VoidCallback onTap) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon,  color: theme.colorScheme.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
  int _tapCount = 0;
  Widget _buildFooter() {
    final theme = Theme.of(context);
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final info = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: GestureDetector(
            onTap: () async {
            _tapCount++;
            if (_tapCount >= 7) {
              _tapCount = 0; 
              bool currentMode = await UserDefaults.isDemoMode();
              await UserDefaults.setDemoMode(!currentMode);
              eventBus.fire(DemoMode(isActive: !currentMode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(!currentMode ? "Demo Mode Activated" : "Demo Mode Deactivated"),
                  backgroundColor: theme.colorScheme.primary,
                ),
              );
            }
           
          },
            child: Center(
              child: Column(
                children: [
                  Text(
                    'App Version ${info.version}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '© ${DateTime.now().year} Proudly Kenyan',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSimPicker() async{
  final isDefault = await SmsService.isDefaultSmsApp();
    if (!isDefault) {
      SmsService.requestDefaultSmsRole();
      return;
    }
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => const SimPicker(),
    );
    setState(() {});
  }
}

class SimPicker extends StatefulWidget {
  const SimPicker({super.key});

  @override
  State<SimPicker> createState() => _SimPickerState();
}

class _SimPickerState extends State<SimPicker> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: FutureBuilder<AppSimCardState>(
        future: SmsService().getSimState(),
        builder: (context, sn) {
          final bool isLoading = sn.connectionState == ConnectionState.waiting;
      
          final bool hasData = sn.hasData && sn.data!.allCards.isNotEmpty;
      
          final simCardState = sn.data;
         
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (!hasData) {
            return const Center(child: Text("No SIM cards detected"));
          }
          return ListView.builder(
              itemCount: simCardState?.allCards.length,
              itemBuilder: (context, index) {
                int slot = int.tryParse(
                        simCardState!.allCards[index].slotIndex.toString()) ??
                    -1;
                return ListTile(
                  onTap: () {
                    SmsService().setDefaultSim(slot);
                    Navigator.pop(context);
                  },
                  selected: slot == simCardState.defaultCard,
                  leading: Icon(Icons.sim_card,
                      color: AppSimCardState.getSimcardColor(
                          simCardState.allCards[index].carrierName)),
                  title: Text(
                      'SIM ${slot + 1} (${simCardState.allCards[index].displayName})'),
                );
              });
        },
      ),
    );
  }
}
