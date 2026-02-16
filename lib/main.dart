import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/app_startup_cubit.dart';
import 'package:messaging/screens/permissions_screen.dart';
import 'package:messaging/services/purchase_service.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'screens/chats_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PurchaseService().initializeIAP();
  runApp(MultiProvider(providers: [
    BlocProvider(create: (c)=>AppStartupCubit()),
  ],child: const MyApp(),),);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMS App',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      home: BlocBuilder<AppStartupCubit, AppStartupState>(
        builder: (context, state) {
          if (state is AppStartupLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (state is AppStartupLoaded) {
            return const ChatsScreen();
            // return const MyWidget();
          } else {
            return const PermissionsScreen();
          }
        },
      ),
    );
  }
}
