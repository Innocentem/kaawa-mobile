import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'widgets/compact_loader.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  bool _loading = false;
  bool _authenticated = false;

  static const _adminPhone = '0751433267';
  static const _adminPassword = 'Admin#123';

  Future<void> _login() async {
    setState(() => _loading = true);
    final phone = _phoneController.text.trim();
    final pass = _passController.text;
    await Future.delayed(const Duration(milliseconds: 300));
    if (phone == _adminPhone && pass == _adminPassword) {
      setState(() {
        _authenticated = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid admin credentials')));
    }
    setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    setState(() {});
  }

  Future<void> _handleReset(int id, String phoneNumber) async {
    final newPassPlain = 'newpass123';
    final hashed = sha256.convert(utf8.encode(newPassPlain)).toString();
    final ok = await DatabaseHelper.instance.adminSetUserPasswordByPhone(phoneNumber, hashed);
    if (ok) {
      await DatabaseHelper.instance.markPasswordResetHandled(id, adminName: 'admin');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset for $phoneNumber -> $newPassPlain (user must change on next login)')));
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _authenticated ? FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseHelper.instance.getPendingPasswordResetRequests(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CompactLoader());
            final rows = snap.data ?? [];
            if (rows.isEmpty) return const Center(child: Text('No pending password reset requests'));
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final r = rows[i];
                  return ListTile(
                    title: Text(r['phoneNumber'] ?? ''),
                    subtitle: Text('Requested: ${r['requestedAt'] ?? ''}'),
                    trailing: ElevatedButton(
                      onPressed: () => _handleReset(r['id'] as int, r['phoneNumber'] as String),
                      child: const Text('Reset'),
                    ),
                  );
                },
              ),
            );
          },
        ) : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Admin phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading ? const SizedBox(width: 20, height: 20, child: CompactLoader(size:20, strokeWidth:2.0)) : const Text('Login as Admin'),
            ),
          ],
        ),
      ),
    );
  }
}
