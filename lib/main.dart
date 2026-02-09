
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
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        themeMode: theme.themeMode,
        home: const InitialScreen(),
      ),
    );
  }
}
