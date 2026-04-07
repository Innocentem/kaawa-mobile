import 'package:flutter/material.dart';
import 'package:kaawa/auth_service.dart';
import 'package:kaawa/buyer_home_screen.dart';
import 'package:kaawa/data/database_helper.dart';
import 'package:kaawa/data/user_data.dart';
import 'package:kaawa/farmer_home_screen.dart';
import 'package:kaawa/farmer_registration_screen.dart';
import 'package:kaawa/buyer_registration_screen.dart';
import 'package:kaawa/login_screen.dart';
import 'package:kaawa/theme/theme.dart';
import 'package:kaawa/forgot_password_screen.dart';
import 'package:kaawa/contact_admin_screen.dart';
import 'package:kaawa/admin_registration_screen.dart';
import 'package:kaawa/admin_home_screen.dart';
import 'package:kaawa/change_password_screen.dart';
import 'package:provider/provider.dart';

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
          if (user.isSuspended) {
            final remaining = user.suspensionRemainingText;
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
                      if (remaining != null) ...[
                        const SizedBox(height: 6),
                        Text('Time left: $remaining'),
                      ],
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

          // Check if the user needs to change their password
          if (user.mustChangePassword) {
            // Navigate to the change password screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ChangePasswordScreen(user: user)),
            );
            return;
          }

          if (user.userType == UserType.farmer) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => FarmerHomeScreen(farmer: user)),
            );
          } else if (user.userType == UserType.admin) {
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

  void _showAboutDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('About Kaawa'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kaawa is a direct-to-consumer coffee marketplace that connects farmers with buyers.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Key Features:',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildFeatureItem(theme, Icons.agriculture, 'Farmers can list their coffee products'),
              _buildFeatureItem(theme, Icons.shopping_cart, 'Buyers can browse and purchase coffee'),
              _buildFeatureItem(theme, Icons.message, 'Direct messaging with farmers'),
              _buildFeatureItem(theme, Icons.star, 'Rate and review sellers'),
              _buildFeatureItem(theme, Icons.location_on, 'Distance-based search and filtering'),
              const SizedBox(height: 16),
              Text(
                'How to Get Started:',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildStepItem(theme, '1', 'Register as a Farmer or Buyer'),
              _buildStepItem(theme, '2', 'Complete your profile'),
              _buildStepItem(theme, '3', 'Farmers: Add your coffee listings'),
              _buildStepItem(theme, '4', 'Buyers: Browse and add items to cart'),
              _buildStepItem(theme, '5', 'Contact farmers directly to finalize purchases'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha((0.3 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Questions or Support?',
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use the "Contact Admin" option to reach out to us anytime.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(ThemeData theme, String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    // icon color should come from theme's iconTheme for consistency and accessibility
    final iconColor = IconTheme.of(context).color ?? theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
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
            // Theme toggle and About info top-right
            Positioned(
              right: 12,
              top: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    // show dark_mode / light_mode depending on current ThemeMode and let the surrounding theme determine color
                    icon: Icon(
                      themeNotifier.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                      color: IconTheme.of(context).color ?? theme.colorScheme.onBackground,
                    ),
                    onPressed: () => themeNotifier.toggleTheme(),
                    tooltip: 'Toggle theme',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.info_outline,
                      color: IconTheme.of(context).color ?? theme.colorScheme.onBackground,
                    ),
                    onPressed: () => _showAboutDialog(context, theme),
                    tooltip: 'About Kaawa',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
