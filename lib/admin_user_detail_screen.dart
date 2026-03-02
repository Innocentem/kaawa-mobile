import 'package:flutter/material.dart';
import '../widgets/compact_loader.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'admin/admin_user_listings_screen.dart';
import 'admin/admin_conversations_list_screen.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final User user;
  const AdminUserDetailScreen({super.key, required this.user});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  late Future<Map<String, dynamic>> _activityFuture;
  late User _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _activityFuture = DatabaseHelper.instance.getUserActivitySummary(widget.user.id!);
    _reloadUser();
  }

  Future<void> _reloadUser() async {
    final fresh = await DatabaseHelper.instance.getUserById(widget.user.id!);
    if (fresh == null) return;
    if (!mounted) return;
    setState(() => _user = fresh);
  }

  Future<void> _suspend(Duration d) async {
    final until = DateTime.now().add(d);
    await DatabaseHelper.instance.suspendUser(widget.user.id!, until);
    await _reloadUser();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User suspended until ${until.toLocal()}')));
  }

  Future<void> _unsuspend() async {
    await DatabaseHelper.instance.unsuspendUser(widget.user.id!);
    await _reloadUser();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unsuspended')));
  }

  Future<void> _resetPassword() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set a temporary password for this user.'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Temporary password',
                hintText: 'Minimum 6 characters',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
        ],
      ),
    );

    if (confirmed != true) return;
    final tempPassword = controller.text.trim();
    if (tempPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Temporary password must be at least 6 characters.')));
      return;
    }

    final hash = sha256.convert(utf8.encode(tempPassword)).toString();
    final ok = await DatabaseHelper.instance.adminSetUserPasswordById(widget.user.id!, hash);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reset password.')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Password reset. Share the temporary password with the user.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    return Scaffold(
      appBar: AppBar(title: Text(u.fullName)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phone: ${u.phoneNumber}'),
            Text('District: ${u.district}'),
            Text('Type: ${u.userType.name}'),
            const SizedBox(height: 12),
            if (u.suspendedUntil != null && u.suspendedUntil!.isAfter(DateTime.now()))
              Text('Suspended until: ${u.suspendedUntil!.toLocal()}'),
            const SizedBox(height: 12),
            // Responsive action buttons - use LayoutBuilder and make buttons full-width on narrow screens
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 420;
                Widget makeButton({required IconData icon, required String label, required VoidCallback onPressed}) {
                  final btn = ElevatedButton.icon(
                    icon: Icon(icon),
                    label: Text(label),
                    onPressed: onPressed,
                  );
                  if (isNarrow) {
                    return SizedBox(width: double.infinity, child: btn);
                  }
                  return btn;
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    makeButton(
                      icon: Icons.hourglass_bottom,
                      label: 'Suspend 1 day',
                      onPressed: () async {
                        final until = DateTime.now().add(const Duration(days: 1));
                        await _showSuspendDialog(until);
                      },
                    ),
                    makeButton(
                      icon: Icons.event,
                      label: 'Suspend 7 days',
                      onPressed: () async {
                        final until = DateTime.now().add(const Duration(days: 7));
                        await _showSuspendDialog(until);
                      },
                    ),
                    makeButton(
                      icon: Icons.schedule,
                      label: 'Suspend (custom)',
                      onPressed: () async {
                        await _pickCustomSuspend();
                      },
                    ),
                    makeButton(
                      icon: Icons.lock_reset,
                      label: 'Reset password',
                      onPressed: _resetPassword,
                    ),
                    makeButton(
                      icon: Icons.remove_circle_outline,
                      label: 'Unsuspend',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Confirm unsuspend'),
                            content: const Text('Are you sure you want to remove suspension for this user?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Unsuspend')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await _unsuspend();
                        }
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('Activity summary'),
            FutureBuilder<Map<String, dynamic>>(
              future: _activityFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const CompactLoader();
                final data = snap.data ?? {};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Listings: ${data['listingsCount'] ?? 0}'),
                    Text('Interests: ${data['interestsCount'] ?? 0}'),
                    Text('Conversations: ${data['conversationsCount'] ?? 0}'),
                    Text('First activity: ${data['earliestActivityIso'] ?? 'N/A'}'),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final convList = AdminConversationsListScreen(userId: widget.user.id!);
                Navigator.push(context, MaterialPageRoute(builder: (c) => convList));
              },
              child: const Text('View Conversations'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                final listingsScreen = AdminUserListingsScreen(userId: widget.user.id!);
                Navigator.push(context, MaterialPageRoute(builder: (c) => listingsScreen));
              },
              child: const Text('View Listings'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSuspendDialog(DateTime until) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Suspend user'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Suspend until: ${until.toLocal()}'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final reason = reasonController.text.trim().isEmpty ? null : reasonController.text.trim();
      await DatabaseHelper.instance.suspendUserWithReason(widget.user.id!, until, reason);
      await _reloadUser();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User suspended until ${until.toLocal()}')));
    }
  }

  Future<void> _pickCustomSuspend() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (time == null) return;
    final until = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await _showSuspendDialog(until);
  }
}
