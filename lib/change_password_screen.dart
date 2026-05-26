import 'package:flutter/material.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/compact_loader.dart';

class ChangePasswordScreen extends StatefulWidget {
  final kaawa.User user;
  const ChangePasswordScreen({super.key, required this.user});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      // 1. Update password in Supabase Auth
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPassword.text),
      );

      // 2. Update profile to clear must_change_password flag
      final updatedUser = widget.user.copyWith(mustChangePassword: false);
      await SupabaseService.instance.updateProfile(updatedUser);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
      
      // Navigate back to the appropriate home screen or first route
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update password: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/icons/pngwing.png',
          height: 32,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'Change Password',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              TextFormField(
                controller: _newPassword,
                decoration: InputDecoration(
                  labelText: 'New password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                obscureText: _obscureNew,
                validator: (v) => (v == null || v.isEmpty) ? 'Enter new password' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                obscureText: _obscureConfirm,
                validator: (v) => (v != _newPassword.text) ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const CompactLoader(size: 18, strokeWidth: 2.0, semanticsLabel: 'Saving') : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
