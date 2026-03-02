import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import './admin_user_detail_screen.dart';
import '../widgets/compact_loader.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  late Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = DatabaseHelper.instance.getAllUsersWithStatus();
  }

  Future<void> _refresh() async {
    setState(() => _usersFuture = DatabaseHelper.instance.getAllUsersWithStatus());
  }

  Widget _statusBadge(User u) {
    if (u.isSuspended) {
      final remaining = u.suspensionRemainingText;
      final untilText = u.suspendedUntil!.toLocal().toString().split('.').first;
      final label = remaining == null ? 'Suspended until $untilText' : 'Suspended ($remaining)';
      return Chip(
        label: Text(label),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _userTile(User u) {
    return ListTile(
      title: Text(u.fullName),
      subtitle: Text('${u.phoneNumber} • ${u.userType.name}'),
      trailing: _statusBadge(u),
      onTap: () async {
        final detail = AdminUserDetailScreen(user: u);
        await Navigator.push(context, MaterialPageRoute(builder: (c) => detail));
        await _refresh();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All users')),
      body: FutureBuilder<List<User>>(
        future: _usersFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CompactLoader());
          final users = snap.data ?? [];
          final suspended = users.where((u) => u.isSuspended).toList();
          final active = users.where((u) => !u.isSuspended).toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: [
                if (suspended.isNotEmpty) _sectionHeader('Suspended users'),
                ...suspended.map((u) => _userTile(u)),
                if (suspended.isNotEmpty && active.isNotEmpty) const Divider(height: 1),
                if (active.isNotEmpty) _sectionHeader('Active users'),
                ...active.map((u) => _userTile(u)),
                if (users.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No users found')),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
