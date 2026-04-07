import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kaawa/data/user_data.dart';
import 'package:kaawa/data/message_data.dart';
import 'package:kaawa/data/database_helper.dart';
import 'package:kaawa/chat_screen.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/widgets/compact_loader.dart';

class PurchaseRequestsScreen extends StatefulWidget {
  final User farmer;
  const PurchaseRequestsScreen({super.key, required this.farmer});

  @override
  State<PurchaseRequestsScreen> createState() => _PurchaseRequestsScreenState();
}

class _PurchaseRequestsScreenState extends State<PurchaseRequestsScreen> {
  late Future<List<Message>> _purchaseRequestsFuture;

  @override
  void initState() {
    super.initState();
    _purchaseRequestsFuture = DatabaseHelper.instance.getPurchaseRequestsForFarmer(widget.farmer.id!);
  }

  Future<User?> _getBuyerInfo(int buyerId) async {
    return await DatabaseHelper.instance.getUserById(buyerId);
  }

  Widget _buildPurchaseRequestCard(BuildContext context, Message message, User? buyer, ThemeData theme) {
    try {
      final data = jsonDecode(message.purchaseRequestData!);
      final items = (data['items'] as List?) ?? [];
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: InkWell(
          onTap: () {
            if (buyer != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    currentUser: widget.farmer,
                    otherUser: buyer,
                  ),
                ),
              ).then((_) {
                setState(() {
                  _purchaseRequestsFuture = DatabaseHelper.instance.getPurchaseRequestsForFarmer(widget.farmer.id!);
                });
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Buyer info
                if (buyer != null)
                  Row(
                    children: [
                      AppAvatar(
                        filePath: buyer.profilePicturePath,
                        imageUrl: buyer.profilePicturePath,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              buyer.fullName,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              buyer.district,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: const Text('Purchase Request'),
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                    ],
                  )
                else
                  Chip(
                    label: const Text('Unknown Buyer'),
                    backgroundColor: theme.colorScheme.errorContainer,
                  ),
                const SizedBox(height: 12),

                // Items details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (items.isNotEmpty)
                        ...List.generate(
                          items.length,
                          (idx) {
                            final item = items[idx];
                            final coffeeType = item['coffeeType'] ?? 'Unknown';
                            final quantityKg = item['quantityKg'] ?? 0;
                            final pricePerKg = item['pricePerKg'] ?? 0;
                            final totalPrice = item['totalPrice'] ?? 0;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (idx > 0) const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            coffeeType,
                                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            '$quantityKg Kg @ UGX $pricePerKg/Kg',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'UGX ${totalPrice.toStringAsFixed(0)}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        )
                      else
                        Text(
                          'No items found',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (items.isNotEmpty) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount:',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'UGX ${totalAmount.toStringAsFixed(0)}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Message preview
                if (message.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.outline.withAlpha((0.3 * 255).round())),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Message:',
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message.text,
                          style: theme.textTheme.bodySmall,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],

                // Timestamp
                const SizedBox(height: 12),
                Text(
                  'Sent: ${DateFormat('MMM d, yyyy • h:mm a').format(message.timestamp)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                // Action button
                const SizedBox(height: 12),
                if (buyer != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              currentUser: widget.farmer,
                              otherUser: buyer,
                            ),
                          ),
                        ).then((_) {
                          setState(() {
                            _purchaseRequestsFuture = DatabaseHelper.instance.getPurchaseRequestsForFarmer(widget.farmer.id!);
                          });
                        });
                      },
                      icon: const Icon(Icons.chat),
                      label: const Text('Reply to Buyer'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Error displaying purchase request',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message.text,
                style: theme.textTheme.bodySmall,
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
        title: const Text('Purchase Requests'),
      ),
      body: FutureBuilder<List<Message>>(
        future: _purchaseRequestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CompactLoader(size: 28, strokeWidth: 3.0, semanticsLabel: 'Loading purchase requests'),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Error loading purchase requests'),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), style: theme.textTheme.bodySmall),
                ],
              ),
            );
          } else {
            final requests = snapshot.data ?? [];
            return requests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 64, color: theme.colorScheme.primary.withAlpha((0.5 * 255).round())),
                        const SizedBox(height: 16),
                        Text('No purchase requests yet', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Buyers will send their purchase requests here', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return FutureBuilder<User?>(
                        future: _getBuyerInfo(request.senderId),
                        builder: (context, buyerSnapshot) {
                          final buyer = buyerSnapshot.data;
                          return _buildPurchaseRequestCard(context, request, buyer, theme);
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

