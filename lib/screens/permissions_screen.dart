import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/permissions_cubit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'conversations_screen.dart';

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PermissionsCubit()..checkAll(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Setup Permissions')),
        body: BlocBuilder<PermissionsCubit, PermissionsState>(
          builder: (context, state) {
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _PermissionTile(
                        title: 'SMS Access',
                        subtitle: 'Required to read and send messages',
                        status: state.statuses[Permission.sms],
                        onTap: () => context.read<PermissionsCubit>().request(Permission.sms),
                      ),
                      _PermissionTile(
                        title: 'Contacts',
                        subtitle: 'To show names instead of numbers',
                        status: state.statuses[Permission.contacts],
                        onTap: () => context.read<PermissionsCubit>().request(Permission.contacts),
                      ),
                      _PermissionTile(
                        title: 'Phone',
                        subtitle: 'Required for technical SMS features',
                        status: state.statuses[Permission.phone],
                        onTap: () => context.read<PermissionsCubit>().request(Permission.phone),
                      ),
                      _PermissionTile(
                        title: 'Notifications',
                        subtitle: 'Alerts for new messages',
                        status: state.statuses[Permission.notification],
                        onTap: () => context.read<PermissionsCubit>().request(Permission.notification),
                      ),
                      _PermissionTile(
                        title: 'Default SMS App',
                        subtitle: 'Necessary to handle system messaging',
                        isGrantedOverride: state.isDefaultApp,
                        onTap: () => context.read<PermissionsCubit>().requestDefaultRole(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.allGranted 
                        ? () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ConversationsScreen()))
                        : null,
                      child: const Text('Continue to Messages'),
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
}

class _PermissionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final PermissionStatus? status;
  final bool? isGrantedOverride;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.title,
    required this.subtitle,
    this.status,
    this.isGrantedOverride,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isGranted = isGrantedOverride ?? (status?.isGranted ?? false);
    final bool isPermanentlyDenied = status?.isPermanentlyDenied ?? false;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: isGranted 
            ? Colors.green.withAlpha(25) 
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          isGranted ? Icons.check : Icons.lock_open_outlined,
          color: isGranted ? Colors.green : Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: isGranted
          ? const Icon(Icons.check_circle, color: Colors.green)
          : FilledButton.tonal(
              onPressed: isPermanentlyDenied ? () => openAppSettings() : onTap,
              child: Text(isPermanentlyDenied ? 'Settings' : 'Grant'),
            ),
    );
  }
}