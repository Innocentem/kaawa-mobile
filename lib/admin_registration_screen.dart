import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';

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
  bool _submitting = false;

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
      // Check if a user with this phone already exists
      final existing = await DatabaseHelper.instance.getUser(phone);
      final hashed = sha256.convert(utf8.encode(password)).toString();

      if (existing != null) {
        // If already admin, we're done. Otherwise promote to admin and update password.
        if (existing.userType == UserType.admin) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin account already exists')));
          Navigator.pop(context);
          return;
        } else {
          final promoted = User(
            id: existing.id,
            fullName: existing.fullName.isNotEmpty ? existing.fullName : 'Kaawa Admin',
            phoneNumber: existing.phoneNumber,
            district: existing.district.isNotEmpty ? existing.district : 'HQ',
            password: hashed,
            userType: UserType.admin,
            mustChangePassword: true,
            profilePicturePath: existing.profilePicturePath,
            latitude: existing.latitude,
            longitude: existing.longitude,
            village: existing.village,
          );
          await DatabaseHelper.instance.updateUser(promoted);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account promoted to admin')));
          Navigator.pop(context);
          return;
        }
      }

      // Create a minimal admin user (fill required fields with sensible defaults)
      final newUser = User(
        fullName: 'Kaawa Admin',
        phoneNumber: phone,
        district: 'HQ',
        password: hashed,
        userType: UserType.admin,
        mustChangePassword: true,
      );

      await DatabaseHelper.instance.insertUser(newUser);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin registered successfully')));
      Navigator.pop(context);
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
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitting ? null : _registerAdmin,
                child: _submitting ? const CircularProgressIndicator() : const Text('Register as Admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
