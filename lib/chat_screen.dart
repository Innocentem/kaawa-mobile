
import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/coffee_stock_data.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/message_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final User currentUser;
  final User otherUser;
  final String? initialMessage;
  final CoffeeStock? coffeeStock;

  const ChatScreen({
    super.key,
    required this.currentUser,
    required this.otherUser,
    this.initialMessage,
    this.coffeeStock,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  late Future<List<Message>> _messagesFuture;
  CoffeeStock? _coffeeStock;

  @override
  void initState() {
    super.initState();
    _coffeeStock = widget.coffeeStock;
    _messagesFuture = _getMessages();
    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
    }
    DatabaseHelper.instance.markMessagesAsRead(widget.currentUser.id!, widget.otherUser.id!);
  }

  Future<List<Message>> _getMessages() async {
    final messages = await DatabaseHelper.instance.getMessages(widget.currentUser.id!, widget.otherUser.id!);
    if (_coffeeStock == null && messages.isNotEmpty) {
      final firstMessage = messages.first;
      if (firstMessage.coffeeStockId != null) {
        final stock = await DatabaseHelper.instance.getCoffeeStockById(firstMessage.coffeeStockId!);
        setState(() {
          _coffeeStock = stock;
        });
      }
    }
    return messages;
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      final message = Message(
        senderId: widget.currentUser.id!,
        receiverId: widget.otherUser.id!,
        text: _messageController.text,
        timestamp: DateTime.now(),
        coffeeStockId: _coffeeStock?.id,
      );

      await DatabaseHelper.instance.insertMessage(message);

      _messageController.clear();
      setState(() {
        _messagesFuture = _getMessages();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUser.fullName),
      ),
      body: Column(
        children: [
          if (_coffeeStock != null)
            Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inquiry about: ${_coffeeStock!.coffeeType}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('${_coffeeStock!.quantity} kg available at UGX ${_coffeeStock!.pricePerKg}/kg'),
                  ],
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Message>>(
              future: _messagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages.'));
                } else {
                  final messages = snapshot.data ?? [];
                  return ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == widget.currentUser.id;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? Theme.of(context).primaryColor : Colors.grey[300],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.text,
                                style: TextStyle(color: isMe ? Colors.white : Colors.black),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat.jm().format(message.timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
