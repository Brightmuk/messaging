import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/permissions_cubit.dart';
import 'package:messaging/screens/chats_screen.dart';
import 'package:messaging/screens/onboarding.dart';
import 'package:messaging/screens/permissions_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  void _setupEdgeToEdge(BuildContext context) async {
    final theme = Theme.of(context);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarIconBrightness: theme.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
    );

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _setupEdgeToEdge(context);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PermissionsCubit, PermissionsState>(
      builder: (context, state) {
        switch (state.status) {
          case AppLifecycleStatus.onboarding:
            return const MfichaOnboarding();

          case AppLifecycleStatus.promptPermissions:
            return const PermissionsScreen();

          case AppLifecycleStatus.authenticated:
            return const ChatsScreen();

          case AppLifecycleStatus.initial:
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
        }
      },
    );
  }
}
