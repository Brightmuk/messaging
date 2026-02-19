import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/permissions_cubit.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'chats_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>  with WidgetsBindingObserver {
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
    }
  }

  Future<void> _checkDefaultSmsStatus() async {
    await SmsService.isDefaultSmsApp();
    setState((){});
  }
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PermissionsCubit()..checkAll(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Required Permissions')),
        body: BlocBuilder<PermissionsCubit, PermissionsState>(
          builder: (context, state) {
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      _PermissionTile(
                        title: 'SMS Access',
                        subtitle: 'Required to show and send messages',
                        status: state.statuses[Permission.sms],
                        onTap: () => context.read<PermissionsCubit>().request(Permission.sms),
                      ),
                      _PermissionTile(
                        title: 'Contacts',
                        subtitle: 'To show contact names and numbers',
                        status: state.statuses[Permission.contacts],
                        onTap: () => context.read<PermissionsCubit>().request(Permission.contacts),
                      ),
                      _PermissionTile(
                        title: 'Notifications',
                        subtitle: 'Alerts for new messages',
                        status: state.statuses[Permission.notification],
                        onTap: () => context.read<PermissionsCubit>().request(Permission.notification),
                      ),
                      _PermissionTile(
                        title: 'Phone',
                        subtitle: 'Required for selecting default sim card',
                        status: state.statuses[Permission.phone],
                        onTap: () => context.read<PermissionsCubit>().request(Permission.phone),
                      ),
                      _PermissionTile(
                        title: 'Default SMS App',
                        subtitle: 'Necessary to handle system messaging',
                        isGrantedOverride: state.isDefaultApp,
                        onTap: () async{
                          await context.read<PermissionsCubit>().requestDefaultRole();
                          
                        },
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
                        ? () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatsScreen()))
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