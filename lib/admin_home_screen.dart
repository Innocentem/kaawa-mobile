import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/admin_user_list_screen.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/admin_password_resets_screen.dart';
import 'package:kaawa_mobile/conversations_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final User admin;
  const AdminHomeScreen({super.key, required this.admin});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _pendingResets = 0;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final rows = await DatabaseHelper.instance.getPendingPasswordResetRequests();
    setState(() => _pendingResets = rows.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings, size: 42),
                const SizedBox(width: 12),
                Expanded(child: Text('Welcome, ${widget.admin.fullName}', style: Theme.of(context).textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.people),
              label: const Text('Manage Users'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminUserListScreen())),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.lock_reset),
              label: Text('Pending Password Resets ($_pendingResets)'),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminPasswordResetsScreen()));
                await _loadPending();
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.message),
              label: const Text('Messages'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => ConversationsScreen(currentUser: widget.admin)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
