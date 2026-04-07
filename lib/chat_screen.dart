import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:kaawa/data/coffee_stock_data.dart';
import 'package:kaawa/data/user_data.dart';
import 'package:kaawa/data/message_data.dart';
import 'package:kaawa/data/database_helper.dart';
import 'package:kaawa/widgets/compact_loader.dart';
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

  Widget _buildPurchaseRequestBubble(BuildContext context, Message message, bool isMe, ThemeData theme) {
    try {
      final data = jsonDecode(message.purchaseRequestData!);
      final items = (data['items'] as List?) ?? [];
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          decoration: BoxDecoration(
            color: isMe ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMe ? theme.colorScheme.onPrimary.withAlpha((0.2 * 255).round()) : theme.colorScheme.outline,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shopping_cart,
                      size: 20,
                      color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Purchase Request',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (items.isNotEmpty)
                  ...List.generate(
                    items.length,
                    (idx) {
                      final item = items[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['coffeeType'] ?? 'Unknown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${item['quantityKg']} Kg @ UGX ${item['pricePerKg']}/Kg',
                              style: TextStyle(
                                fontSize: 12,
                                color: isMe ? theme.colorScheme.onPrimary.withAlpha((0.8 * 255).round()) : theme.colorScheme.onSurfaceVariant.withAlpha((0.8 * 255).round()),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'UGX ${totalAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (message.text.isNotEmpty && message.text != 'Purchase request for multiple items')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isMe ? theme.colorScheme.onPrimary.withAlpha((0.1 * 255).round()) : theme.colorScheme.primary.withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            fontSize: 12,
                            color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.jm().format(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? theme.colorScheme.onPrimary.withAlpha((0.7 * 255).round()) : theme.colorScheme.onSurfaceVariant.withAlpha((0.6 * 255).round()),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      // Fallback to text message if parsing fails
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? theme.colorScheme.primary : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat.jm().format(message.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? theme.colorScheme.onPrimary.withAlpha((0.7 * 255).round()) : theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  return const Center(child: SizedBox(height: 200, child: Center(child: CompactLoader(size: 28, strokeWidth: 3.0, semanticsLabel: 'Loading messages'))));
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages.'));
                } else {
                  final messages = snapshot.data ?? [];
                  return ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == widget.currentUser.id;

                      if (message.isPurchaseRequest && message.purchaseRequestData != null) {
                        return _buildPurchaseRequestBubble(context, message, isMe, theme);
                      }

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? theme.colorScheme.primary : theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.text,
                                style: TextStyle(color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat.jm().format(message.timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe ? theme.colorScheme.onPrimary.withAlpha((0.7 * 255).round()) : theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
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
