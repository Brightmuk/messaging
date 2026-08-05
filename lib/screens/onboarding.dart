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
      title: "\"Siri Yako, Simu Yako.\"",
      body:
          "Every text including M-PESA, is stored directly on your phone's memory. We dont store messages on a server",
      painterBuilder: (colors) => _LocalOnlyPainter(colors: colors),
    ),
    OnboardingSlide(
      title: "\"Onyesha message\"",
      body:
          "Optionally hide your account balances from M-PESA and Airtel Money messages, keeping your financial information private.",
      painterBuilder: (colors) => _BalanceRedactionPainter(colors: colors),
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
            // // 1. Fixed Header
            // Text(
            //   "M-Ficha",
            //   style: theme.textTheme.titleLarge!.copyWith(
            //     color: theme.colorScheme.primary,
            //     fontWeight: FontWeight.w600,
            //   ),
            // ),
            // Text(
            //   "Messaging",
            //   style: theme.textTheme.bodyMedium!.copyWith(
            //     color: theme.colorScheme.onSurface.withAlpha(100),
            //   ),
            // ),

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
                      child: const Text("Get started"),
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
          const TextSpan(text: 'By tapping Get started you accept \nour '),
          TextSpan(
            text: 'Terms of Service',
            style: TextStyle(color: theme.colorScheme.primary),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _launchURL('https://brimukon.com/m-ficha/terms'),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(color: theme.colorScheme.primary),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _launchURL('https://brimukon.com/m-ficha/privacy'),
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
  final CustomPainter Function(ColorScheme colors) painterBuilder;
  OnboardingSlide({
    required this.title,
    required this.body,
    required this.painterBuilder,
  });
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
          SizedBox(
            height: 220,
            width: 220,
            child: CustomPaint(
              painter: slide.painterBuilder(theme.colorScheme),
            ),
          ),
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

/// Illustration 1: a phone with chat bubbles and a padlock badge,
/// representing the "local-only, on your phone" promise.
class _LocalOnlyPainter extends CustomPainter {
  final ColorScheme colors;
  _LocalOnlyPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.5,
        height: size.height * 0.85,
      ),
      const Radius.circular(28),
    );
    canvas.drawRRect(phoneRect, Paint()..color = colors.surfaceContainerHighest);
    canvas.drawRRect(
      phoneRect,
      Paint()
        ..color = colors.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Notch
    final notchRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, phoneRect.top + 16),
        width: 36,
        height: 6,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(notchRect, Paint()..color = colors.outlineVariant);

    // Chat bubbles, alternating sides
    final bubbleWidths = [0.6, 0.4, 0.5];
    double y = phoneRect.top + 44;
    for (var i = 0; i < bubbleWidths.length; i++) {
      final w = phoneRect.width * bubbleWidths[i];
      final alignLeft = i.isEven;
      final left = alignLeft ? phoneRect.left + 14 : phoneRect.right - 14 - w;
      final bubbleRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, y, w, 18),
        const Radius.circular(9),
      );
      canvas.drawRRect(
        bubbleRect,
        Paint()..color = alignLeft ? colors.primaryContainer : colors.surface,
      );
      if (!alignLeft) {
        canvas.drawRRect(
          bubbleRect,
          Paint()
            ..color = colors.outlineVariant
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      y += 28;
    }

    // Lock badge
    final badgeCenter = Offset(phoneRect.right - 6, phoneRect.bottom - 30);
    canvas.drawCircle(badgeCenter, 34, Paint()..color = colors.primary);
    canvas.drawCircle(
      badgeCenter,
      34,
      Paint()
        ..color = colors.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    _drawLock(canvas, badgeCenter, colors.onPrimary);
  }

  void _drawLock(Canvas canvas, Offset center, Color color) {
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 5), width: 22, height: 16),
      const Radius.circular(3),
    );
    canvas.drawRRect(bodyRect, Paint()..color = color);

    final shacklePath = Path()
      ..moveTo(center.dx - 7, center.dy - 3)
      ..lineTo(center.dx - 7, center.dy - 9)
      ..arcToPoint(
        Offset(center.dx + 7, center.dy - 9),
        radius: const Radius.circular(7),
        clockwise: true,
      )
      ..lineTo(center.dx + 7, center.dy - 3);
    canvas.drawPath(
      shacklePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LocalOnlyPainter oldDelegate) => oldDelegate.colors != colors;
}

/// Illustration 2: a message card with a redacted balance bar and an
/// eye-slash badge, representing balance redaction.
class _BalanceRedactionPainter extends CustomPainter {
  final ColorScheme colors;
  _BalanceRedactionPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.12,
        size.height * 0.14,
        size.width * 0.76,
        size.height * 0.62,
      ),
      const Radius.circular(16),
    );
    canvas.drawRRect(cardRect, Paint()..color = colors.surfaceContainerHighest);
    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = colors.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Header label (e.g. "M-PESA")
    final headerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardRect.left + 20, cardRect.top + 20, cardRect.width * 0.35, 10),
      const Radius.circular(5),
    );
    canvas.drawRRect(headerRect, Paint()..color = colors.primary);

    // Redacted balance bar with a hatched "hidden" texture
    final balanceRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardRect.left + 20, cardRect.top + 46, cardRect.width * 0.6, 22),
      const Radius.circular(6),
    );
    canvas.drawRRect(balanceRect, Paint()..color = colors.onSurfaceVariant.withAlpha(200));
    final hatchPaint = Paint()
      ..color = colors.surfaceContainerHighest
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (double x = balanceRect.left + 6; x < balanceRect.right - 4; x += 10) {
      canvas.drawLine(
        Offset(x, balanceRect.top + 4),
        Offset(x + 5, balanceRect.bottom - 4),
        hatchPaint,
      );
    }

    // Two smaller detail lines below (still visible, unredacted)
    for (int i = 0; i < 2; i++) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cardRect.left + 20,
          cardRect.top + 84 + i * 18,
          cardRect.width * (i == 0 ? 0.5 : 0.3),
          8,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(r, Paint()..color = colors.outlineVariant);
    }

    // Eye-slash badge
    final badgeCenter = Offset(cardRect.right - 10, cardRect.bottom - 10);
    canvas.drawCircle(badgeCenter, 30, Paint()..color = colors.primary);
    canvas.drawCircle(
      badgeCenter,
      30,
      Paint()
        ..color = colors.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    _drawEyeSlash(canvas, badgeCenter, colors.onPrimary);
  }

  void _drawEyeSlash(Canvas canvas, Offset center, Color color) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final eyePath = Path()
      ..moveTo(center.dx - 11, center.dy)
      ..quadraticBezierTo(center.dx, center.dy - 9, center.dx + 11, center.dy)
      ..quadraticBezierTo(center.dx, center.dy + 9, center.dx - 11, center.dy);
    canvas.drawPath(eyePath, strokePaint);
    canvas.drawCircle(center, 3.5, Paint()..color = color);

    canvas.drawLine(
      Offset(center.dx - 13, center.dy + 10),
      Offset(center.dx + 13, center.dy - 10),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BalanceRedactionPainter oldDelegate) =>
      oldDelegate.colors != colors;
}