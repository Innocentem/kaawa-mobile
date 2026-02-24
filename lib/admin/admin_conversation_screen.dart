import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/data/message_data.dart';

class AdminConversationScreen extends StatefulWidget {
  final int userId;
  final int otherUserId;
  const AdminConversationScreen({super.key, required this.userId, required this.otherUserId});

  @override
  State<AdminConversationScreen> createState() => _AdminConversationScreenState();
}

class _AdminConversationScreenState extends State<AdminConversationScreen> {
  late Future<List<Message>> _messagesFuture;

  @override
  void initState() {
    super.initState();
    _messagesFuture = DatabaseHelper.instance.getMessages(widget.userId, widget.otherUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: FutureBuilder<List<Message>>(
        future: _messagesFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final msgs = snap.data ?? [];
          if (msgs.isEmpty) return const Center(child: Text('No messages'));
          return ListView.builder(
            itemCount: msgs.length,
            itemBuilder: (context, i) {
              final m = msgs[i];
              return ListTile(
                title: Text(m.text),
                subtitle: Text(m.timestamp.toLocal().toString().split('.').first),
              );
            },
          );
        },
      ),
    );
  }
}

