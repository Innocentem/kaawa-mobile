import 'package:flutter/material.dart';
import 'package:kaawa/theme/theme.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kaawa/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kaawa/widgets/chat_overlay_manager.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On desktop platforms initialize the ffi implementation and set the
  // global `databaseFactory` so `sqflite`'s `openDatabase` works.
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Supabase.initialize(
    url: 'https://buluwzoktzotgqrmhewo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1bHV3em9rdHpvdGdxcm1oZXdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwNDAyNTksImV4cCI6MjA5NDYxNjI1OX0.FsEQyJqyaYM1gfL4nhu34cmoko0SqHv3JbVRdiBp0eo',
  );

  final themeNotifier = ThemeNotifier();
  await themeNotifier.isReady;

  runApp(
    ChangeNotifierProvider.value(
      value: themeNotifier,
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
          scaffoldBackgroundColor: Colors.transparent,
          canvasColor: Colors.transparent,
          // App bar uses scaffold bg and primary for icons
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
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
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: _FadePageTransitionsBuilder(),
              TargetPlatform.iOS: _FadePageTransitionsBuilder(),
              TargetPlatform.linux: _FadePageTransitionsBuilder(),
              TargetPlatform.macOS: _FadePageTransitionsBuilder(),
              TargetPlatform.windows: _FadePageTransitionsBuilder(),
            },
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFFD740),
            secondary: Color(0xFFBCAAA4),
            surface: Color(0xFF3E2723),
            background: Color(0xFF1B110F),
            onPrimary: Color(0xFF471C09),
            onSurface: Colors.white,
          ),
          brightness: Brightness.dark,
          primaryColor: const Color(0xFFFFD740),
          fontFamily: 'Quicksand',
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Quicksand', bodyColor: Colors.white, displayColor: Colors.white).copyWith(
            headlineLarge: ThemeData.dark().textTheme.headlineLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            headlineMedium: ThemeData.dark().textTheme.headlineMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
            titleLarge: ThemeData.dark().textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFFFFD740)),
          ),
          scaffoldBackgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Color(0xFFFFD740)),
          cardColor: const Color(0xFF3E2723),
          hintColor: const Color(0xFFBCAAA4),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD740),
              foregroundColor: const Color(0xFF471C09),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFD740)),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFFD740),
              side: const BorderSide(color: Color(0xFFFFD740)),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Color(0xFFFFD740)),
            actionsIconTheme: IconThemeData(color: Color(0xFFFFD740)),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFFFFD740),
            foregroundColor: Color(0xFF471C09),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1C0A04).withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF5D4037))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFD740))),
            labelStyle: const TextStyle(color: Color(0xFFFFD740)),
            hintStyle: const TextStyle(color: Color(0xFFBCAAA4)),
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: _FadePageTransitionsBuilder(),
              TargetPlatform.iOS: _FadePageTransitionsBuilder(),
              TargetPlatform.linux: _FadePageTransitionsBuilder(),
              TargetPlatform.macOS: _FadePageTransitionsBuilder(),
              TargetPlatform.windows: _FadePageTransitionsBuilder(),
            },
          ),
        ),
        themeMode: theme.themeMode,
        home: const InitialScreen(),
        builder: (context, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          if (child == null) return const SizedBox.shrink();

          return StreamBuilder<kaawa.User?>(
            stream: AuthService().currentUserDataStream,
            builder: (context, snapshot) {
              final currentUser = snapshot.data;
              Widget content = child;

              if (currentUser != null) {
                content = ChatOverlayManager(
                  currentUser: currentUser,
                  child: child,
                );
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    isDark ? 'assets/images/bg.jpg' : 'assets/images/white.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    excludeFromSemantics: true,
                  ),
                  if (!isDark)
                    Container(
                      color: const Color(0xFFFFFFFF).withAlpha((0.08 * 255).round()),
                    ),
                  content,
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(opacity: animation, child: child);
  }
}
