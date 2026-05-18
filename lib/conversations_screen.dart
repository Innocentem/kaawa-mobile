import 'package:flutter/material.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/chat_screen.dart';
import 'package:kaawa/data/conversation_data.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/widgets/compact_loader.dart';

class ConversationsScreen extends StatefulWidget {
  final kaawa.User currentUser;

  const ConversationsScreen({super.key, required this.currentUser});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late Stream<List<Conversation>> _conversationsStream;

  @override
  void initState() {
    super.initState();
    _conversationsStream = SupabaseService.instance.getConversationsStream(widget.currentUser.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: _conversationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: SizedBox(height: 200, child: Center(child: CompactLoader(size: 28, strokeWidth: 3.0, semanticsLabel: 'Loading conversations'))));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading conversations: ${snapshot.error}'));
          } else {
            final conversations = snapshot.data ?? [];
            return conversations.isEmpty
                ? const Center(child: Text('You have no conversations yet.'))
                : ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      final otherUser = conversation.otherUser;
                      final lastMessage = conversation.lastMessage;
                      final coffeeStock = conversation.coffeeStock;

                      return ListTile(
                        leading: Material(
                          type: MaterialType.transparency,
                          child: AppAvatar(
                            filePath: otherUser.profilePicturePath,
                            imageUrl: otherUser.profilePicturePath,
                            size: 40,
                          ),
                        ),
                        title: Text(otherUser.fullName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lastMessage.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: lastMessage.isRead || lastMessage.senderId == widget.currentUser.id 
                                    ? FontWeight.normal 
                                    : FontWeight.bold,
                              ),
                            ),
                            if (coffeeStock != null)
                              Text(
                                'Inquiry about: ${coffeeStock.coffeeType}',
                                style: const TextStyle(fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: (lastMessage.isRead || lastMessage.senderId == widget.currentUser.id)
                            ? null
                            : Icon(Icons.circle, color: Theme.of(context).colorScheme.error, size: 12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                currentUser: widget.currentUser,
                                otherUser: otherUser,
                                coffeeStock: coffeeStock,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
          }
        },
      ),
    );
  }
}
