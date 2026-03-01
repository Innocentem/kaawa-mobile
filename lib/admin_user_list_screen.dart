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
    if (u.suspendedUntil != null && u.suspendedUntil!.isAfter(DateTime.now())) {
      return Chip(
        label: Text('Suspended until ${u.suspendedUntil!.toLocal().toString().split('.').first}'),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
      );
    }
    return const SizedBox.shrink();
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
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final u = users[i];
                return ListTile(
                  title: Text(u.fullName),
                  subtitle: Text('${u.phoneNumber} • ${u.userType.name}'),
                  trailing: _statusBadge(u),
                  onTap: () {
                    final detail = AdminUserDetailScreen(user: u);
                    Navigator.push(context, MaterialPageRoute(builder: (c) => detail));
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
