
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/chat_screen.dart';
import 'package:kaawa_mobile/data/conversation_data.dart';

class ConversationsScreen extends StatefulWidget {
  final User currentUser;

  const ConversationsScreen({super.key, required this.currentUser});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late Future<List<Conversation>> _conversationsFuture;

  @override
  void initState() {
    super.initState();
    _conversationsFuture = _getConversations();
  }

  Future<List<Conversation>> _getConversations() async {
    return await DatabaseHelper.instance.getConversations(widget.currentUser.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: FutureBuilder<List<Conversation>>(
        future: _conversationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading conversations.'));
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
                        leading: CircleAvatar(
                          backgroundImage: otherUser.profilePicturePath != null
                              ? FileImage(File(otherUser.profilePicturePath!))
                              : null,
                          child: otherUser.profilePicturePath == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(otherUser.fullName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lastMessage.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                        trailing: lastMessage.isRead
                            ? null
                            : const Icon(Icons.circle, color: Colors.red, size: 12),
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
                          ).then((_) {
                            setState(() {
                              _conversationsFuture = _getConversations();
                            });
                          });
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
