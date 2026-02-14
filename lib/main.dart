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
          brightness: Brightness.light,
          primaryColor: const Color(0xFF8D6E63),
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF8D6E63),
            secondary: Color(0xFFBCAAA4),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFF8D6E63))),
            labelStyle: const TextStyle(color: Colors.black54),
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF3E2723),
          scaffoldBackgroundColor: const Color(0xFF212121),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF3E2723),
            secondary: Color(0xFF5D4037),
          ),
          cardColor: const Color(0xFF1E1E1E),
          dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF262626), titleTextStyle: TextStyle(color: Colors.white, fontSize: 18)),
          elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3E2723))),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF2B2B2B), foregroundColor: Colors.white, elevation: 1),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            // use surface color with slight elevation for contrast in dark mode
            fillColor: const Color(0xFF2A2A2A),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade700)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFF3E2723))),
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
