import 'package:flutter/material.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/admin_user_detail_screen.dart';
import '../widgets/compact_loader.dart';

class AdminUserListScreen extends StatefulWidget {
  final kaawa.User admin;
  const AdminUserListScreen({super.key, required this.admin});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  late Future<List<kaawa.User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _usersFuture = SupabaseService.instance.getAllProfiles();
    });
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _userTile(kaawa.User u) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: u.isSuspended ? Colors.grey : Colors.brown[100],
        child: Text(u.fullName.substring(0, 1).toUpperCase()),
      ),
      title: Text(u.fullName),
      subtitle: Text('${u.userType.name} • ${u.phoneNumber}'),
      trailing: u.isSuspended ? const Icon(Icons.block, color: Colors.red, size: 16) : null,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => AdminUserDetailScreen(user: u, admin: widget.admin),
          ),
        );
        await _refresh();
      },
    );
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
      body: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Users',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<kaawa.User>>(
              future: _usersFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Center(child: CompactLoader());
                final users = (snap.data ?? []).where((u) => u.userType != kaawa.UserType.admin).toList();
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
          ),
        ],
      ),
    );
  }
}
