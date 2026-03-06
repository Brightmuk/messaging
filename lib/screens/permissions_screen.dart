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
          title: const Text("Final Steps"),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.verified_user_outlined,
                      size: 30, color: Colors.blue),
                  const SizedBox(height: 24),
                  Text(
                    "To protect your privacy and organize your inbox, M-Ficha uses these permissions",
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  const _PermissionInfoTile(
                    icon: Icons.message_outlined,
                    title: "SMS Access",
                    desc: "To redact sensitive account balance in Mpesa/Airtel Money transaction messages, and manage messages",
                  ),
                  const _PermissionInfoTile(
                    icon: Icons.contacts_outlined,
                    title: "Contacts",
                    desc:
                        "To show contact names and phone numbers of your saved contacts",
                  ),
                  const _PermissionInfoTile(
                    icon: Icons.notifications_active_outlined,
                    title: "Notifications",
                    desc: "To alert you of new  messages and other important updates.",
                  ),
                  const _PermissionInfoTile(
                    icon: Icons.phone_android_outlined,
                    title: "Phone State",
                    desc: "To allow management of Dual sim card states",
                  ),
                ],
              ),
            ),

            // Persistent "Continue" button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () =>
                      context.read<PermissionsCubit>().requestAllRemaining(),
                  child: const Text("Continue"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

void _showExplanationSheet(BuildContext context, Permission permission) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle for M3 feel
          Container(height: 4, width: 32, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          
          const Icon(Icons.settings_suggest_outlined, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          
          Text("Finish setup", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
        Text("Settings", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.outline),
        Text("Permissions", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.outline),
        Text(permissionName, style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary, 
          fontWeight: FontWeight.bold
        )),
        Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.outline),
        Text("Allow", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
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
