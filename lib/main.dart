import 'package:flutter/material.dart';
import 'package:kaawa_mobile/theme/theme.dart';
import 'package:kaawa_mobile/welcome_screen.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, theme, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Kaawa Mobile',
        theme: ThemeData(
          // light color scheme (central source for light colors)
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF471C09),
            secondary: Color(0xFFBCAAA4),
            surface: Color(0xFFFFFFFF),
            background: Color(0xFFF5F5F5),
            onPrimary: Color(0xFFFFFFFF),
            onSurface: Color(0xFF471C09),
          ),
          brightness: Brightness.light,
          primaryColor: const Color(0xFF471C09),
          fontFamily: 'Quicksand',
          // base text theme tuned for sizes and consistent font
          textTheme: (() {
            final base = ThemeData.light().textTheme.apply(fontFamily: 'Quicksand');
            // tune sizes to be slightly larger and ensure headings are bold
            return base.copyWith(
              headlineLarge: base.headlineLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.bold),
              headlineMedium: base.headlineMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
              headlineSmall: base.headlineSmall?.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
              titleLarge: base.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
              titleMedium: base.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
              bodyLarge: base.bodyLarge?.copyWith(fontSize: 16),
              bodyMedium: base.bodyMedium?.copyWith(fontSize: 14),
              bodySmall: base.bodySmall?.copyWith(fontSize: 12),
              labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            );
          })(),
          // use colorScheme for icon colors so widgets follow theme
          iconTheme: const IconThemeData(color: Color(0xFF471C09)),
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          // App bar uses scaffold bg and primary for icons
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFFF5F5F5),
            foregroundColor: const Color(0xFF471C09),
            elevation: 0,
            iconTheme: const IconThemeData(color: Color(0xFF471C09)),
            actionsIconTheme: const IconThemeData(color: Color(0xFF471C09)),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: const Color(0xFF471C09),
            foregroundColor: ColorScheme.light().onPrimary,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF471C09),
              foregroundColor: ColorScheme.light().onPrimary,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF471C09),
              side: const BorderSide(color: Color(0xFF471C09)),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF471C09)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: ColorScheme.light().surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ColorScheme.light().onSurface.withAlpha((0.06 * 255).round()))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8D6E63))),
            labelStyle: const TextStyle(color: Color(0xFF471C09)),
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        darkTheme: ThemeData(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF3E2723),
            secondary: Color(0xFF5D4037),
            surface: Color(0xFF471C09),
            background: Color(0xFF471C09),
            onPrimary: Colors.white,
            onSurface: Colors.white,
          ),
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF3E2723),
          fontFamily: 'Quicksand',
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Quicksand', bodyColor: Colors.white, displayColor: Colors.white).copyWith(
            headlineLarge: ThemeData.dark().textTheme.headlineLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.bold),
            headlineMedium: ThemeData.dark().textTheme.headlineMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
            titleLarge: ThemeData.dark().textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          scaffoldBackgroundColor: const Color(0xFF471C09),
          iconTheme: const IconThemeData(color: Color(0xFFFFD740)),
          cardColor: const Color(0xFF1E1E1E),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3E2723),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(color: Colors.white),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2B2B2B),
            foregroundColor: Colors.white,
            elevation: 1,
            iconTheme: IconThemeData(color: Color(0xFFFFD740)),
            actionsIconTheme: IconThemeData(color: Color(0xFFFFD740)),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF3E2723),
            foregroundColor: Colors.white,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1C0A04),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade700)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3E2723))),
            labelStyle: TextStyle(color: Colors.grey.shade300),
            hintStyle: TextStyle(color: Colors.grey.shade500),
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        themeMode: theme.themeMode,
        home: const InitialScreen(),
      ),
    );
  }
}
