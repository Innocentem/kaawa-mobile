import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/data/message_data.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/widgets/app_avatar.dart';
import '../../widgets/compact_loader.dart';

class AdminConversationScreen extends StatefulWidget {
  final int userId;
  final int otherUserId;
  const AdminConversationScreen({super.key, required this.userId, required this.otherUserId});

  @override
  State<AdminConversationScreen> createState() => _AdminConversationScreenState();
}

class _AdminConversationScreenState extends State<AdminConversationScreen> {
  late Future<List<Message>> _messagesFuture;
  User? _user;
  User? _otherUser;

  @override
  void initState() {
    super.initState();
    _messagesFuture = _loadConversation();
  }

  Future<List<Message>> _loadConversation() async {
    // load both users for display
    _user = await DatabaseHelper.instance.getUserById(widget.userId);
    _otherUser = await DatabaseHelper.instance.getUserById(widget.otherUserId);
    // fetch full two-way thread
    final msgs = await DatabaseHelper.instance.getMessages(widget.userId, widget.otherUserId);
    return msgs;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_otherUser?.fullName ?? 'Conversation'),
      ),
      body: FutureBuilder<List<Message>>(
        future: _messagesFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CompactLoader());
          final msgs = snap.data ?? [];
          if (msgs.isEmpty) return const Center(child: Text('No messages'));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            itemCount: msgs.length,
            itemBuilder: (context, i) {
              final m = msgs[i];
              final isFromUser = m.senderId == widget.userId;
              final sender = isFromUser ? _user : _otherUser;

              // message bubble
              final bubble = Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                decoration: BoxDecoration(
                  color: isFromUser ? theme.colorScheme.primary : theme.cardColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isFromUser ? 12 : 2),
                    bottomRight: Radius.circular(isFromUser ? 2 : 12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sender != null) ...[
                      Text(
                        sender.fullName,
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: isFromUser ? theme.colorScheme.onPrimary : null),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      m.text,
                      style: TextStyle(color: isFromUser ? theme.colorScheme.onPrimary : null),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.timestamp.toLocal().toString().split('.').first,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: isFromUser ? theme.colorScheme.onPrimary.withAlpha((0.7 * 255).round()) : theme.textTheme.bodySmall?.color == null ? null : theme.textTheme.bodySmall!.color!.withAlpha((0.7 * 255).round())),
                    ),
                  ],
                ),
              );

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: isFromUser
                      ? [
                          // user's message on right
                          Flexible(child: bubble),
                          const SizedBox(width: 8),
                          if (_user != null)
                            AppAvatar(filePath: _user!.profilePicturePath, imageUrl: _user!.profilePicturePath, size: 36),
                        ]
                      : [
                          if (_otherUser != null)
                            AppAvatar(filePath: _otherUser!.profilePicturePath, imageUrl: _otherUser!.profilePicturePath, size: 36),
                          const SizedBox(width: 8),
                          Flexible(child: bubble),
                        ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
