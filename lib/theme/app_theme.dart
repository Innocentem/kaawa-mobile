import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Main theme configuration for Kaawa Mobile
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      
      // Color scheme
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryBrown,
        secondary: AppColors.primaryGreen,
        tertiary: AppColors.lightBrown,
        surface: AppColors.cream,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textDark,
        onError: Colors.white,
      ),
      
      // Typography
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(color: AppColors.textDark),
        displayMedium: AppTypography.displayMedium.copyWith(color: AppColors.textDark),
        displaySmall: AppTypography.displaySmall.copyWith(color: AppColors.textDark),
        headlineLarge: AppTypography.headlineLarge.copyWith(color: AppColors.textDark),
        headlineMedium: AppTypography.headlineMedium.copyWith(color: AppColors.textDark),
        headlineSmall: AppTypography.headlineSmall.copyWith(color: AppColors.textDark),
        titleLarge: AppTypography.titleLarge.copyWith(color: AppColors.textDark),
        titleMedium: AppTypography.titleMedium.copyWith(color: AppColors.textDark),
        titleSmall: AppTypography.titleSmall.copyWith(color: AppColors.textDark),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: AppColors.textDark),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: AppColors.textMedium),
        bodySmall: AppTypography.bodySmall.copyWith(color: AppColors.textMedium),
        labelLarge: AppTypography.labelLarge.copyWith(color: AppColors.textMedium),
        labelMedium: AppTypography.labelMedium.copyWith(color: AppColors.textMedium),
        labelSmall: AppTypography.labelSmall.copyWith(color: AppColors.textLight),
      ),
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primaryBrown,
        foregroundColor: Colors.white,
        titleTextStyle: AppTypography.headlineMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      
      // ElevatedButton theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBrown,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.button,
        ),
      ),
      
      // OutlinedButton theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBrown,
          side: const BorderSide(color: AppColors.primaryBrown, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.button,
        ),
      ),
      
      // TextButton theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBrown,
          textStyle: AppTypography.button,
        ),
      ),
      
      // InputDecoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.beige, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.beige, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBrown, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMedium),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textLight),
        errorStyle: AppTypography.bodySmall.copyWith(color: AppColors.error),
      ),
      
      // Card theme
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      
      // IconButton theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.primaryBrown,
        ),
      ),
      
      // FloatingActionButton theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      // Scaffold background
      scaffoldBackgroundColor: AppColors.cream,
      
      // Divider theme
      dividerTheme: DividerThemeData(
        color: AppColors.beige,
        thickness: 1,
        space: 1,
      ),
      
      // SnackBar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkBrown,
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  // Page transition animations
  static PageRouteBuilder<T> createRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        
        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        
        var offsetAnimation = animation.drive(tween);
        
        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
  
  // Fade route for modals
  static PageRouteBuilder<T> createFadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
    );
  }
}
