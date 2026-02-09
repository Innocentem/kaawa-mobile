
import 'package:flutter/material.dart';
import 'package:kaawa_mobile/auth_service.dart';
import 'package:kaawa_mobile/buyer_home_screen.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/farmer_home_screen.dart';
import 'package:kaawa_mobile/farmer_registration_screen.dart';
import 'package:kaawa_mobile/buyer_registration_screen.dart';
import 'package:kaawa_mobile/login_screen.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Kaawa'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              child: const Text('Login'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text("Don't have an account?"),
            const SizedBox(height: 8),
            ElevatedButton(
              child: const Text('Register as a Farmer'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FarmerRegistrationScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              child: const Text('Register as a Buyer'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BuyerRegistrationScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
