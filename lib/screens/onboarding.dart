import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:flutter/services.dart';
import 'package:messaging/cubit/app_startup_cubit.dart';
import 'package:provider/provider.dart';

class MfichaOnboarding extends StatelessWidget {
  const MfichaOnboarding({super.key});


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntroductionScreen(
      globalHeader:  SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child:  Text("M-Ficha Messaging", style: theme.textTheme.titleMedium!.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),),
      
      ))),
      pages: [
          PageViewModel(
          title: "\"Onyesha message\"",
          body: "Optionally hide your account balances from M-PESA and Airtel Money messages, keeping your financial information private.",
          image: Image.asset('assets/images/balance_redaction.png', height: 200),
          decoration:  PageDecoration(titleTextStyle: theme.textTheme.titleLarge!,bodyTextStyle: theme.textTheme.bodyMedium!),
        ),
        PageViewModel(
          title: "\"Siri Yako, Simu Yako.\"",
          body: "A private messaging app built for Kenyans. Your messages are always saved on device",
          image:  Image.asset('assets/images/private_messaging.png', height: 200),
          decoration:  PageDecoration(titleTextStyle: theme.textTheme.titleLarge!,bodyTextStyle: theme.textTheme.bodyMedium!),
        ),

      ],
      onDone: () => context.read<AppStartupCubit>().viewOnboarding(),
      onSkip: () => context.read<AppStartupCubit>().viewOnboarding(),
      showSkipButton: true,
      skip: const Text("Skip"),
      next: const Icon(Icons.arrow_forward),
      done: const Text("Done", style: TextStyle(fontWeight: FontWeight.w600)),
      dotsDecorator: DotsDecorator(
        size: const Size.square(10.0),
        activeSize: const Size(20.0, 10.0),
        activeColor: theme.colorScheme.primary,
        color: Colors.black26,
        spacing: const EdgeInsets.symmetric(horizontal: 3.0),
        activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
      ),
    );
      
  }
}