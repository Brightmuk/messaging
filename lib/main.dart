import 'dart:ui';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/permissions_cubit.dart';
import 'package:messaging/cubit/user_preference_cubit.dart';
import 'package:messaging/main_wrapper.dart';
import 'package:messaging/screens/widgets/privacy_overlay.dart';
import 'package:messaging/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  await setupDependencies();
  runApp(globalProvider);
}

final MultiProvider globalProvider = MultiProvider(
  providers: [
    BlocProvider(create: (c) => PermissionsCubit()),
    BlocProvider(create: (c) => UserPreferenceCubit())
  ],
  child: const MyApp(),
);
Future<void> setupDependencies() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupFirebase();
}

Future<void> setupFirebase() async {
  await Firebase.initializeApp();

  if (kDebugMode) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
  } else {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  await NotificationService().initialize();
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
          home: MainWrapper()
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
