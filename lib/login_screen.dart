import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:kaawa_mobile/auth_service.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/farmer_home_screen.dart';
import 'package:kaawa_mobile/buyer_home_screen.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/forgot_password_screen.dart';
import 'package:kaawa_mobile/contact_admin_screen.dart';
import 'package:kaawa_mobile/change_password_screen.dart';
import 'package:kaawa_mobile/admin_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _keepLoggedIn = false;
  bool _showResetBanner = false;
  final AuthService _authService = AuthService();

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
          child: Column(
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
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              Row(
                children: [
                  Checkbox(
                    value: _keepLoggedIn,
                    onChanged: (value) {
                      setState(() {
                        _keepLoggedIn = value!;
                      });
                    },
                  ),
                  const Text('Keep me logged in'),
                ],
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
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final phoneNumber = _phoneNumberController.text.trim();
                    final user = await DatabaseHelper.instance.getUser(phoneNumber);

                    if (user != null) {
                      setState(() {
                        _showResetBanner = user.mustChangePassword;
                      });
                      if (user.isSuspended) {
                        final remaining = user.suspensionRemainingText;
                        await showDialog<void>(
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
                              TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => ContactAdminScreen(currentUser: user))), child: const Text('Contact Admin')),
                            ],
                          ),
                        );
                        return;
                      }

                      final hashedPassword = sha256.convert(utf8.encode(_passwordController.text)).toString();
                      if (user.password == hashedPassword) {
                        if (_keepLoggedIn) {
                          await _authService.login(user.id!);
                        }
                        if (user.mustChangePassword) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (c) => ChangePasswordScreen(user: user)),
                          );
                          return;
                        }
                        // Navigate to the correct home screen based on user type
                        if (user.userType == UserType.farmer) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FarmerHomeScreen(farmer: user),
                            ),
                          );
                        } else if (user.userType == UserType.admin) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (c) => AdminHomeScreen(admin: user)),
                          );
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BuyerHomeScreen(buyer: user),
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Incorrect password.')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No user found with that phone number.')),
                      );
                    }
                  }
                },
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
