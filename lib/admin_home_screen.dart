import 'package:flutter/material.dart';
import 'package:kaawa/data/user_data.dart';
import 'package:kaawa/admin_user_list_screen.dart';
import 'package:kaawa/data/database_helper.dart';
import 'package:kaawa/admin_password_resets_screen.dart';
import 'package:kaawa/conversations_screen.dart';
import 'package:kaawa/widgets/icon_action_tile.dart';
import 'package:kaawa/auth_service.dart';
import 'package:kaawa/welcome_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final User admin;
  const AdminHomeScreen({super.key, required this.admin});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _pendingResets = 0;
  int _unreadMessageCount = 0;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadPending();
    _loadUnreadMessages();
  }

  Future<void> _loadPending() async {
    final rows = await DatabaseHelper.instance.getPendingPasswordResetRequests();
    setState(() => _pendingResets = rows.length);
  }

  Future<void> _loadUnreadMessages() async {
    final count = await DatabaseHelper.instance.getUnreadMessageCount(widget.admin.id!);
    if (!mounted) return;
    setState(() => _unreadMessageCount = count);
  }

  Future<void> _handleLogoutRequest() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Do you really want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Logout')),
        ],
      ),
    );

    if (shouldLogout != true) return;
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (c) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        await _handleLogoutRequest();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _handleLogoutRequest,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.admin_panel_settings, size: 40, color: IconTheme.of(context).color ?? theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Hi, ${widget.admin.fullName}', style: theme.textTheme.titleLarge)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  IconActionTile(
                    icon: Icons.people,
                    label: 'Users',
                    tooltip: 'Manage users',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AdminUserListScreen(admin: widget.admin))),
                  ),
                  IconActionTile(
                    icon: Icons.lock_reset,
                    label: 'Resets',
                    tooltip: 'Pending password resets',
                    badgeText: '$_pendingResets',
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminPasswordResetsScreen()));
                      await _loadPending();
                    },
                  ),
                  IconActionTile(
                    icon: Icons.message,
                    label: 'Messages',
                    tooltip: 'View conversations',
                    badgeText: '$_unreadMessageCount',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => ConversationsScreen(currentUser: widget.admin)),
                      );
                      await _loadUnreadMessages();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
