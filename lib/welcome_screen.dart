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
          // Block auto-login when user is suspended
          if (user.suspendedUntil != null && user.suspendedUntil!.isAfter(DateTime.now())) {
            // clear stored login and inform user
            await _authService.logout();
            // show suspension dialog on the next frame so context is ready
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Account suspended'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your account is suspended until ${user.suspendedUntil!.toLocal()}.'),
                      const SizedBox(height: 8),
                      if (user.suspensionReason != null && user.suspensionReason!.isNotEmpty)
                        Text('Reason: ${user.suspensionReason}'),
                      const SizedBox(height: 12),
                      const Text('If you believe this is a mistake, contact admin.'),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
                    TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => const ContactAdminScreen())), child: const Text('Contact Admin')),
                  ],
                ),
              );
            });

            return; // do not navigate into the app
          }

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

    // icon color should come from theme's iconTheme for consistency and accessibility
    final iconColor = IconTheme.of(context).color ?? theme.colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
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
                            color: theme.brightness == Brightness.dark ? theme.iconTheme.color : theme.colorScheme.primary,
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

                  const SizedBox(height: 20),

                  // Action buttons (iconized)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Semantics(
                                button: true,
                                label: 'Login',
                                child: Tooltip(
                                  message: 'Login',
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                                        },
                                        iconSize: 40,
                                        icon: Icon(Icons.login, color: iconColor),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Login', style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Semantics(
                                button: true,
                                label: 'Register as Farmer',
                                child: Tooltip(
                                  message: 'Register as Farmer',
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => const FarmerRegistrationScreen()));
                                        },
                                        iconSize: 40,
                                        icon: Icon(Icons.agriculture, color: iconColor),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Farmer', style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Semantics(
                                button: true,
                                label: 'Register as Buyer',
                                child: Tooltip(
                                  message: 'Register as Buyer',
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => const BuyerRegistrationScreen()));
                                        },
                                        iconSize: 40,
                                        icon: Icon(Icons.person_add, color: iconColor),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Buyer', style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // secondary actions (forgot password / contact admin)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
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
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
            // Theme toggle top-right
            Positioned(
              right: 12,
              top: 12,
              child: IconButton(
                // show dark_mode / light_mode depending on current ThemeMode and let the surrounding theme determine color
                icon: Icon(
                  themeNotifier.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                  color: IconTheme.of(context).color ?? theme.colorScheme.onBackground,
                ),
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
