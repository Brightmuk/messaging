import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/permissions_cubit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<PermissionsCubit, PermissionsState>(
      listenWhen: (prev, curr) => curr.lastDeniedPermission != null,
      listener: (context, state) {
        _showExplanationSheet(context, state.lastDeniedPermission!);
        context.read<PermissionsCubit>().resetDeniedTrigger();
      },
      child: Scaffold(
        appBar: AppBar(
         
          centerTitle: true,
        ),
        body: BlocBuilder<PermissionsCubit, PermissionsState>(
          builder: (context, state) {
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, ),
                    children: [
                      const Icon(Icons.security_outlined,
                          size: 40, color: Colors.blue),
                      const SizedBox(height: 16),
                      Text(
                        "Permissions we use",
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "To act as full messenger and provide privacy for your financial transactions, M-Ficha uses these permissions",
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // --- SECTION 1: CORE FUNCTIONALITY ---
                      _buildSectionHeader(theme, "MESSENGER & PRIVACY"),
                        const _PermissionInfoTile(
                        icon: Icons.sms_outlined,
                        title: "SMS Access",
                        desc:
                            "Required to send, receive, and manage your SMS/MMS messages",
                      ),
                      const _PermissionInfoTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: "Read SMS",
                        desc:
                            "Essential for detecting and redacting balances in M-PESA & Airtel Money messages.",
                      ),
                      const SizedBox(height: 24),

                      // --- SECTION 2: DEFAULT APP FEATURES ---
                   
                        _buildSectionHeader(theme, "SMART INBOX FEATURES"),
                        const _PermissionInfoTile(
                          icon: Icons.contacts_outlined,
                          title: "Contacts",
                          desc:
                              "Identifies senders so that you see names from your contact list",
                        ),
                        const _PermissionInfoTile(
                          icon: Icons.sim_card_outlined,
                          title: "Phone & SIM",
                          desc:
                              "This is needed for managing dual-SIM setups.",
                        ),
                        const SizedBox(height: 24),
                      

                      // --- SECTION 3: OPTIONAL ---
                      _buildSectionHeader(theme, "ALERTS"),
                      const _PermissionInfoTile(
                        icon: Icons.notifications_none_outlined,
                        title: "Notifications",
                        desc:
                            "Alerts you when a you receive a new message.",
                      ),
                    ],
                  ),
                ),

                // Footer with Action
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                   
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: () => context
                            .read<PermissionsCubit>()
                            .requestAllRemaining(),
                        child: const Text("Continue"),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showExplanationSheet(BuildContext context, Permission permission) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle for M3 feel
            Container(
                height: 4,
                width: 32,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),

            const Icon(Icons.settings_suggest_outlined,
                size: 48, color: Colors.blue),
            const SizedBox(height: 16),

            Text("Finish setup",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              _getPermissionReason(permission),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 24),

            _buildSettingsPath(context, permission),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await openAppSettings();
                },
                child: const Text("Open App Settings"),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Not Now"),
            ),
          ],
        ),
      ),
    );
  }

  String _getPermissionReason(Permission p) {
    if (p == Permission.sms) {
      return "M-Ficha needs SMS access to redact your balances and manage messages.";
    }
    if (p == Permission.contacts) {
      return "We need Contacts access to show names instead of just numbers in your inbox.";
    }
    if (p == Permission.phone) {
      return "We need Phone permissions for Dual sim card management";
    }
    return "This permission is required for the app to function correctly.";
  }

  String _getPermissionName(Permission p) {
    if (p == Permission.sms) return "SMS";
    if (p == Permission.contacts) return "Contacts";
    if (p == Permission.notification) return "Notifications";
    if (p == Permission.phone) return "Phone";
    return "Permissions";
  }

  Widget _buildSettingsPath(BuildContext context, Permission permission) {
    final theme = Theme.of(context);
    final permissionName = _getPermissionName(permission);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text("Settings",
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.outline),
          Text("Permissions",
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.outline),
          Text(permissionName,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold)),
          Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.outline),
          Text("Allow",
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PermissionInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _PermissionInfoTile(
      {required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(desc,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey[600])),
              ],
            ),
          )
        ],
      ),
    );
  }
}
