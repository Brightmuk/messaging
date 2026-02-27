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

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
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
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PermissionsCubit()..checkAll(),
      child: Builder(builder: (context) {
        return BlocBuilder<PermissionsCubit, PermissionsState>(
          builder: (context, state) {
            return Scaffold(
              appBar: AppBar(),
              body: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Visual anchor
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.security_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Setup M-Ficha',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            RichText(
                              text: TextSpan(
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                children: const [
                                  TextSpan(
                                      text:
                                          'To protect your privacy and manage messages, we need '),
                                  TextSpan(
                                    text: 'essential permissions.',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          children: [
                            _PermissionTile(
                              title: 'SMS Access',
                              subtitle: 'Required to show and send messages',
                              status: state.statuses[Permission.sms],
                              onTap: () => context
                                  .read<PermissionsCubit>()
                                  .request(Permission.sms),
                            ),
                            _PermissionTile(
                              title: 'Contacts',
                              subtitle: 'To show contact names and numbers',
                              status: state.statuses[Permission.contacts],
                              onTap: () => context
                                  .read<PermissionsCubit>()
                                  .request(Permission.contacts),
                            ),
                            _PermissionTile(
                              title: 'Notifications',
                              subtitle: 'Alerts for new messages',
                              status: state.statuses[Permission.notification],
                              onTap: () => context
                                  .read<PermissionsCubit>()
                                  .request(Permission.notification),
                            ),
                            _PermissionTile(
                              title: 'Phone',
                              subtitle:
                                  'Required for selecting default sim card',
                              status: state.statuses[Permission.phone],
                              onTap: () => context
                                  .read<PermissionsCubit>()
                                  .request(Permission.phone),
                            ),
                            _PermissionTile(
                              title: 'Default SMS App',
                              subtitle: 'Necessary to handle system messaging',
                              isGrantedOverride: state.isDefaultApp,
                              onTap: () async {
                                await context
                                    .read<PermissionsCubit>()
                                    .requestDefaultRole();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
              floatingActionButton: SizedBox(
                width: double.infinity,
                height: 45,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton(
                    onPressed: state.allGranted
                        ? () => Navigator.pushReplacement(context,
                            MaterialPageRoute(builder: (_) => const ChatsScreen()))
                        : null,
                    child: const Text('Continue to Messages'),
                  ),
                ),
              ),
            );
          },
        );
      }),
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
    super.key,
    required this.title,
    required this.subtitle,
    this.status,
    this.isGrantedOverride,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isGranted = isGrantedOverride ?? (status?.isGranted ?? false);
    final bool isPermanentlyDenied = status?.isPermanentlyDenied ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          // Subtle green glow for granted, or standard surface for pending
          color: isGranted
              ? Colors.green.withOpacity(0.08)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isGranted ? Colors.green.withOpacity(0.5) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // 1. Icon Container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isGranted
                      ? Colors.green.withOpacity(0.1)
                      : theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGranted
                      ? Icons.check_circle_rounded
                      : Icons.shield_outlined,
                  color: isGranted ? Colors.green : theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // 2. Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isGranted ? Colors.green.shade800 : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Action Button
              if (!isGranted)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: isPermanentlyDenied
                        ? theme.colorScheme.errorContainer
                        : null,
                  ),
                  onPressed:
                      isPermanentlyDenied ? () => openAppSettings() : onTap,
                  child: Text(
                    isPermanentlyDenied ? 'Settings' : 'Grant',
                    style: TextStyle(
                      color:
                          isPermanentlyDenied ? theme.colorScheme.error : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
        ),
      ),
    );
  }
}
