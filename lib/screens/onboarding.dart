import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:messaging/cubit/permissions_cubit.dart';

class MfichaOnboarding extends StatefulWidget {
  const MfichaOnboarding({super.key});

  @override
  State<MfichaOnboarding> createState() => _MfichaOnboardingState();
}

class _MfichaOnboardingState extends State<MfichaOnboarding> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      title: "\"Onyesha message\"",
      body: "Optionally hide your account balances from M-PESA and Airtel Money messages, keeping your financial information private.",
      image: 'assets/images/balance_redaction.png',
    ),
    OnboardingSlide(
      title: "\"Siri Yako, Simu Yako.\"",
      body: "A private messaging app built for Kenyans. Your messages are always saved on device.",
      image: 'assets/images/private_messaging.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
     appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Fixed Header
            Text(
              "M-Ficha",
              style: theme.textTheme.titleLarge!.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "Messaging",
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(100)
                
              ),
            ),

            // 2. The Slider Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _slides.length,
                itemBuilder: (context, index) => _SlideWidget(slide: _slides[index]),
              ),
            ),

            // 3. Page Indicators (Dots)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentPage == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            // 4. Persistent Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: () => context.read<PermissionsCubit>().completeOnboarding(),
                      
                      child: const Text("Get started", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLegalText(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalText(ThemeData theme) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
        children: [
          const TextSpan(text: 'By tapping Get started you accept our '),
          TextSpan(
            text: 'Terms of Service',
            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()..onTap = () => _launchURL('https://brimukon.com/m-ficha/terms'),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()..onTap = () => _launchURL('https://brimukon.com/m-ficha/privacy'),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }
}

class OnboardingSlide {
  final String title;
  final String body;
  final String image;
  OnboardingSlide({required this.title, required this.body, required this.image});
}

class _SlideWidget extends StatelessWidget {
  final OnboardingSlide slide;
  const _SlideWidget({required this.slide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Image.asset(slide.image, height: 220),
          const SizedBox(height: 48),
          Text(
            slide.title,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}