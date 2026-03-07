import 'dart:ui';

import 'package:flutter/material.dart';

class BrandPalette {
  final Color background; // Adaptive tinted background
  final Color accent;     // The bold brand color
  final Color text;       // High-contrast brand text

  BrandPalette({
    required this.background,
    required this.accent,
    required this.text,
  });
}

BrandPalette getBrandPalette(String address, BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final addr = address.toUpperCase();

  // Define Base Brand Colors
  Color brandAccent;
  if (addr.contains("MPESA")) {
    brandAccent = const Color(0xFF2E7D32); // Safaricom Green
  } else if (addr.contains("AIRTEL")) {
    brandAccent = const Color(0xFFC62828); // Airtel Red
  } else {
    brandAccent = theme.colorScheme.primary;
  }

  return BrandPalette(
    // 1. Background: Tint the current surface with the brand color
    // Use low opacity (8-12%) so it adapts to White or Dark Grey backgrounds
    background: Color.alphaBlend(
      brandAccent.withOpacity(isDark ? 0.12 : 0.08), 
      theme.colorScheme.surface
    ),
    
    // 2. Accent: Keep it bold, but slightly lighter in dark mode for accessibility
    accent: isDark ? Color.lerp(brandAccent, Colors.white, 0.2)! : brandAccent,
    
    // 3. Text: High contrast version of the brand color
    text: isDark ? Color.lerp(brandAccent, Colors.white, 0.5)! : brandAccent,
  );
}