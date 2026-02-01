import 'package:flutter/material.dart';

/// Coffee-inspired color palette for Kaawa Mobile
class AppColors {
  // Primary Coffee Browns
  static const Color primaryBrown = Color(0xFF6F4E37); // Coffee brown
  static const Color darkBrown = Color(0xFF3E2723); // Dark roast
  static const Color lightBrown = Color(0xFF8D6E63); // Light roast
  static const Color mediumBrown = Color(0xFF5D4037); // Medium roast

  // Accent Greens (Coffee plant/leaf inspired)
  static const Color primaryGreen = Color(0xFF4CAF50); // Fresh coffee leaf
  static const Color darkGreen = Color(0xFF388E3C); // Deep leaf
  static const Color lightGreen = Color(0xFF81C784); // Young leaf

  // Cream and Neutral Tones
  static const Color cream = Color(0xFFF5F5DC); // Coffee with cream
  static const Color lightCream = Color(0xFFFFFAF0); // Foam
  static const Color warmWhite = Color(0xFFFAF9F6); // Warm background
  static const Color beige = Color(0xFFD7CCC8); // Latte

  // Functional Colors
  static const Color textDark = Color(0xFF212121); // Primary text
  static const Color textMedium = Color(0xFF757575); // Secondary text
  static const Color textLight = Color(0xFF9E9E9E); // Hint text
  
  static const Color error = Color(0xFFD32F2F); // Error state
  static const Color success = Color(0xFF388E3C); // Success state
  static const Color warning = Color(0xFFF57C00); // Warning state
  
  // Gradients
  static const LinearGradient coffeeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6F4E37),
      Color(0xFF5D4037),
    ],
  );

  static const LinearGradient creamGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFAF0),
      Color(0xFFF5F5DC),
    ],
  );
}
