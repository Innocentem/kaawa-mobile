import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'widgets/compact_loader.dart';

class AdminPasswordResetsScreen extends StatefulWidget {
  const AdminPasswordResetsScreen({super.key});

  @override
  State<AdminPasswordResetsScreen> createState() => _AdminPasswordResetsScreenState();
}

class _AdminPasswordResetsScreenState extends State<AdminPasswordResetsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = DatabaseHelper.instance.getPendingPasswordResetRequests();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = DatabaseHelper.instance.getPendingPasswordResetRequests();
    });
  }

  String _generateTempPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#';
    final rand = Random.secure();
    return List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _showTempPasswordDialog(String phoneNumber, String tempPassword) async {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Temporary password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share this temporary password with $phoneNumber.'),
            const SizedBox(height: 8),
            SelectableText(tempPassword, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('This will only be shown once.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: tempPassword));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Temporary password copied')));
            },
            child: const Text('Copy'),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(c), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _handleReset(int id, String phoneNumber) async {
    final tempPassword = _generateTempPassword();
    final hashed = sha256.convert(utf8.encode(tempPassword)).toString();
    final ok = await DatabaseHelper.instance.adminSetUserPasswordByPhone(phoneNumber, hashed);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
      return;
    }

    await DatabaseHelper.instance.markPasswordResetHandled(id, adminName: 'admin');
    if (!mounted) return;
    await _showTempPasswordDialog(phoneNumber, tempPassword);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Password Resets')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CompactLoader());
          }
          final rows = snap.data ?? [];
          if (rows.isEmpty) {
            return const Center(child: Text('No pending password reset requests'));
          }
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
      ),
    );
  }
}

