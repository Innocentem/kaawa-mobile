import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/data/conversation_data.dart';
import './admin_conversation_screen.dart' as acs;
import '../widgets/compact_loader.dart';

class AdminConversationsListScreen extends StatefulWidget {
  final int userId;
  const AdminConversationsListScreen({super.key, required this.userId});

  @override
  State<AdminConversationsListScreen> createState() => _AdminConversationsListScreenState();
}

class _AdminConversationsListScreenState extends State<AdminConversationsListScreen> {
  late Future<List<Conversation>> _convsFuture;

  @override
  void initState() {
    super.initState();
    _convsFuture = DatabaseHelper.instance.getConversations(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body: FutureBuilder<List<Conversation>>(
        future: _convsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CompactLoader());
          final convs = snap.data ?? [];
          if (convs.isEmpty) return const Center(child: Text('No conversations'));
          return ListView.separated(
            itemCount: convs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = convs[i];
              return ListTile(
                title: Text(c.otherUser.fullName),
                subtitle: Text(c.lastMessage.text),
                trailing: Text(c.lastMessage.timestamp.toLocal().toString().split('.').first),
                onTap: () {
                  final convScreen = acs.AdminConversationScreen(userId: widget.userId, otherUserId: c.otherUser.id!);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => convScreen));
                },
              );
            },
          );
        },
      ),
    );
  }
}
