import 'package:flutter/material.dart';

class GlobalGradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final List<Color>? colors;

  const GlobalGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    // Access your theme's primary colors or a custom list
    final List<Color> gradientColors = colors ?? [
      Theme.of(context).colorScheme.primary,
      Colors.purple
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(16),
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: child,
      ),
    );
  }
}