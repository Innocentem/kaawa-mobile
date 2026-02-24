import 'package:flutter/material.dart';
import 'package:kaawa_mobile/auth_service.dart';
import 'package:kaawa_mobile/buyer_home_screen.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/farmer_home_screen.dart';
import 'package:kaawa_mobile/farmer_registration_screen.dart';
import 'package:kaawa_mobile/buyer_registration_screen.dart';
import 'package:kaawa_mobile/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:kaawa_mobile/theme/theme.dart';
import 'package:kaawa_mobile/forgot_password_screen.dart';
import 'package:kaawa_mobile/contact_admin_screen.dart';
import 'package:kaawa_mobile/admin_registration_screen.dart';
import 'package:kaawa_mobile/admin_home_screen.dart';

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      final userId = await _authService.getUserId();
      if (userId != null) {
        final user = await DatabaseHelper.instance.getUserById(userId);
        if (user != null) {
          if (user.userType == UserType.farmer.toString()) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => FarmerHomeScreen(farmer: user)),
            );
          } else if (user.userType == UserType.admin.toString()) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AdminHomeScreen(admin: user)),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => BuyerHomeScreen(buyer: user)),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const WelcomeScreen();
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top image with rounded bottom corners. Long-press the image to open the hidden Admin registration.
                GestureDetector(
                  onLongPress: () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminRegistrationScreen()));
                  },
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                    child: Image.asset(
                      'assets/images/seeds.jpg',
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.45,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Title and subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      Text(
                        'Welcome to Kaawa',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connecting coffee farmers and buyers',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          child: Text(
                            'Login',
                            style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const FarmerRegistrationScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            side: BorderSide(color: theme.colorScheme.primary),
                          ),
                          child: Text(
                            'Register as Farmer',
                            style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Register as Buyer button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const BuyerRegistrationScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            side: BorderSide(color: theme.colorScheme.primary),
                          ),
                          child: Text(
                            'Register as Buyer',
                            style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (c) => const ForgotPasswordScreen()));
                            },
                            child: const Text('Forgot password?'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (c) => const ContactAdminScreen()));
                            },
                            child: const Text('Contact admin'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
            // Theme toggle top-right
            Positioned(
              right: 12,
              top: 12,
              child: IconButton(
                icon: Icon(themeNotifier.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode, color: Colors.white),
                onPressed: () => themeNotifier.toggleTheme(),
                tooltip: 'Toggle theme',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
