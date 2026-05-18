import 'package:flutter/material.dart';
import 'package:kaawa/auth_service.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/farmer_home_screen.dart';
import 'package:kaawa/buyer_home_screen.dart';
import 'package:kaawa/forgot_password_screen.dart';
import 'package:kaawa/contact_admin_screen.dart';
import 'package:kaawa/change_password_screen.dart';
import 'package:kaawa/admin_home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showResetBanner = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final phone = _phoneNumberController.text.trim();
      final password = _passwordController.text;
      final email = '$phone@kaawa.com';

      final response = await _authService.signIn(email: email, password: password);
      final sbUser = response.user;

      if (sbUser != null) {
        final metadata = sbUser.userMetadata ?? {};
        final userTypeStr = metadata['user_type'] ?? 'buyer';
        final fullName = metadata['full_name'] ?? 'User';
        final district = metadata['district'] ?? '';

        // Map Supabase metadata to our User model
        final user = kaawa.User(
          id: sbUser.id,
          fullName: fullName,
          phoneNumber: phone,
          district: district,
          password: '', // Password is not stored locally anymore
          userType: kaawa.UserType.values.firstWhere(
            (e) => e.name == userTypeStr,
            orElse: () => kaawa.UserType.buyer,
          ),
        );

        if (mounted) {
          // Navigate to the correct home screen based on user type
          if (user.userType == kaawa.UserType.farmer) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => FarmerHomeScreen(farmer: user)),
            );
          } else if (user.userType == kaawa.UserType.admin) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => AdminHomeScreen(admin: user)),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => BuyerHomeScreen(buyer: user)),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              if (_showResetBanner)
                MaterialBanner(
                  content: const Text('Password reset by admin — change required.'),
                  actions: [
                    TextButton(
                      onPressed: () => setState(() => _showResetBanner = false),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ForgotPasswordScreen())),
                    child: const Text('Forgot password?'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ContactAdminScreen())),
                    child: const Text('Contact admin'),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
