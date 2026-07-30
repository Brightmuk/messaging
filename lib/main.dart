import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/permissions_cubit.dart';
import 'package:messaging/cubit/user_preference_cubit.dart';
import 'package:messaging/screens/onboarding.dart';
import 'package:messaging/screens/permissions_screen.dart';
import 'package:messaging/screens/widgets/privacy_overlay.dart';
import 'package:messaging/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'screens/chats_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  setupDependencies();
  runApp(globalProvider);
}

final MultiProvider globalProvider = MultiProvider(
  providers: [
    BlocProvider(create: (c) => PermissionsCubit()),
    BlocProvider(create: (c) => UserPreferenceCubit())
  ],
  child: const MyApp(),
);
void setupDependencies() {
  WidgetsFlutterBinding.ensureInitialized();
  setupNotifications();
  setupEdgeToEdge();
    FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

void setupNotifications() async {
  await Firebase.initializeApp();
  NotificationService().initialize();
}

void setupEdgeToEdge() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: true,
    statusBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserPreferenceCubit, UserPreferenceState>(
      builder: (context, preferenceState) {
        return MaterialApp(
          title: 'SMS App',
          navigatorKey: navigatorKey,
          navigatorObservers: [
            routeObserver,
             FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
            ],
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: preferenceState.themeMode,
          home: BlocBuilder<PermissionsCubit, PermissionsState>(
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
          ),
        );
      },
    );
  }
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const PrivacyShieldOverlay(),
    ),
  );
}
