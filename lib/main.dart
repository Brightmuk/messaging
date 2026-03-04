import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:messaging/cubit/payment_cubit.dart';
import 'package:messaging/cubit/permissions_cubit.dart';
import 'package:messaging/screens/onboarding.dart';
import 'package:messaging/screens/permissions_screen.dart';
import 'package:messaging/services/purchase_service.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'screens/chats_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  PurchaseService().initializeIAP();
  runApp(
    MultiProvider(
      providers: [
        BlocProvider(create: (c) => PaymentCubit()),
        BlocProvider(create: (c) => PermissionsCubit())
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMS App',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(context),
      darkTheme: AppTheme.darkTheme(context),
      themeMode: ThemeMode.system,
     home: BlocBuilder<PermissionsCubit, AppLifecycleStatus>(
  builder: (context, status) {
    switch (status) {
      case AppLifecycleStatus.onboarding:
        return const MfichaOnboarding();
      case AppLifecycleStatus.promptPermissions:
        return const PermissionsScreen();
      case AppLifecycleStatus.authenticated:
        return const ChatsScreen();
      case AppLifecycleStatus.initial:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
  },
),
    );
  }
}
