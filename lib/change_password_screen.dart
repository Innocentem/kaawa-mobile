import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/data/user_data.dart';

class ChangePasswordScreen extends StatefulWidget {
  final User user;
  const ChangePasswordScreen({super.key, required this.user});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final hashed = sha256.convert(utf8.encode(_newPassword.text)).toString();
    final updated = User(
      id: widget.user.id,
      fullName: widget.user.fullName,
      phoneNumber: widget.user.phoneNumber,
      district: widget.user.district,
      password: hashed,
      userType: widget.user.userType,
      profilePicturePath: widget.user.profilePicturePath,
      latitude: widget.user.latitude,
      longitude: widget.user.longitude,
      village: widget.user.village,
      mustChangePassword: false,
    );

    await DatabaseHelper.instance.updateUser(updated);
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
    // pop until homescreen or login
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text('Please choose a new password for ${widget.user.fullName}.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPassword,
                decoration: const InputDecoration(labelText: 'New password'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'Password too short' : null,
              ),
              TextFormField(
                controller: _confirm,
                decoration: const InputDecoration(labelText: 'Confirm'),
                obscureText: true,
                validator: (v) => (v != _newPassword.text) ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const CircularProgressIndicator() : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

