import 'package:flutter/material.dart';
import 'package:kaawa/auth_service.dart';
import 'package:kaawa/login_screen.dart';
import 'widgets/compact_loader.dart';

// NOTE: These are the single credentials the app will accept to create an admin account.
// For production, do NOT hard-code credentials. Use a secure server-driven invite/token flow.
const _kAdminPhone = '0751433267';
const _kAdminPassword = 'adMin#026@1';

class AdminRegistrationScreen extends StatefulWidget {
  const AdminRegistrationScreen({super.key});

  @override
  State<AdminRegistrationScreen> createState() => _AdminRegistrationScreenState();
}

class _AdminRegistrationScreenState extends State<AdminRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _submitting = false;
  bool _obscurePassword = true;

  Future<void> _registerAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone != _kAdminPhone || password != _kAdminPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid admin credentials')));
      return;
    }

    setState(() => _submitting = true);

    try {
      final email = '$phone@kaawa.com';
      await _authService.signUp(
        email: email,
        password: password,
        fullName: 'Kaawa Admin',
        phoneNumber: phone,
        userType: 'admin',
        district: 'HQ',
      );

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin registered successfully')));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Registration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('Enter admin phone and password to register the admin account.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone number'),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.isEmpty) ? 'Enter phone' : null,
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
                validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitting ? null : _registerAdmin,
                child: _submitting ? const CompactLoader(size:18, strokeWidth:2.0, semanticsLabel: 'Registering admin') : const Text('Register as Admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
