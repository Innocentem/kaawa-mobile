# Purchase Request Response - Code Examples

## Complete Example: Add Response Status Indicator to Purchase Requests Screen

This example shows how to enhance the `PurchaseRequestsScreen` to display whether each request has been responded to.

```dart
// In purchase_requests_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kaawa/data/user_data.dart';
import 'package:kaawa/data/message_data.dart';
import 'package:kaawa/data/database_helper.dart';
import 'package:kaawa/chat_screen.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/widgets/compact_loader.dart';

class EnhancedPurchaseRequestCard extends StatefulWidget {
  final Message request;
  final User buyer;
  final User farmer;
  final VoidCallback onReplyTap;

  const EnhancedPurchaseRequestCard({
    required this.request,
    required this.buyer,
    required this.farmer,
    required this.onReplyTap,
  });

  @override
  State<EnhancedPurchaseRequestCard> createState() =>
      _EnhancedPurchaseRequestCardState();
}

class _EnhancedPurchaseRequestCardState
    extends State<EnhancedPurchaseRequestCard> {
  late Future<bool> _hasResponseFuture;

  @override
  void initState() {
    super.initState();
    _hasResponseFuture = _checkIfResponded();
  }

  Future<bool> _checkIfResponded() async {
    return await DatabaseHelper.instance.hasRespondedToPurchaseRequest(
      widget.buyer.id!,
      widget.farmer.id!,
      widget.request.timestamp,
    );
  }

  Widget _buildResponseStatus(bool hasResponded, ThemeData theme) {
    if (hasResponded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: theme.colorScheme.tertiary),
            const SizedBox(width: 4),
            Text(
              'Responded',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pending, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 4),
            Text(
              'Pending',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with buyer info and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      AppAvatar(
                        filePath: widget.buyer.profilePicturePath,
                        imageUrl: widget.buyer.profilePicturePath,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.buyer.fullName,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              widget.buyer.district,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                FutureBuilder<bool>(
                  future: _hasResponseFuture,
                  builder: (context, snapshot) {
                    final hasResponded = snapshot.data ?? false;
                    return _buildResponseStatus(hasResponded, theme);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Items details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildItemsDetails(theme),
            ),

            const SizedBox(height: 12),

            // Timestamp and action button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sent: ${DateFormat('MMM d, h:mm a').format(widget.request.timestamp)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onReplyTap,
                  icon: const Icon(Icons.chat),
                  label: const Text('Reply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsDetails(ThemeData theme) {
    try {
      final data = jsonDecode(widget.request.purchaseRequestData!);
      final items = (data['items'] as List?) ?? [];
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isNotEmpty)
            ...List.generate(
              items.length,
              (idx) {
                final item = items[idx];
                return Column(
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
                                item['coffeeType'] ?? 'Unknown',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${item['quantityKg']} Kg @ UGX ${item['pricePerKg']}/Kg',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'UGX ${(item['totalPrice'] as num?)?.toStringAsFixed(0) ?? '0'}',
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
            ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total:',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
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
      );
    } catch (e) {
      return Text(
        'Error loading items',
        style: theme.textTheme.bodySmall,
      );
    }
  }
}
```

## Example: Add Notification Badge to Home Screen

```dart
// Add this to your farmer home screen

class PurchaseRequestNotificationBadge extends StatelessWidget {
  final int farmerId;

  const PurchaseRequestNotificationBadge({
    required this.farmerId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: DatabaseHelper.instance
          .getUnrespondedPurchaseRequestCount(farmerId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        if (count == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onError,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }
}

// Usage in your tab bar or navigation:
// Container(
//   child: Stack(
//     children: [
//       Icon(Icons.shopping_cart),
//       Positioned(
//         right: 0,
//         top: 0,
//         child: PurchaseRequestNotificationBadge(
//           farmerId: currentUser.id!,
//         ),
//       ),
//     ],
//   ),
// )
```

## Example: Quick Response Template System

```dart
// Create a quick response sheet for farmers

class QuickResponseBottomSheet extends StatelessWidget {
  final User farmer;
  final User buyer;
  final Message purchaseRequest;

  const QuickResponseBottomSheet({
    required this.farmer,
    required this.buyer,
    required this.purchaseRequest,
  });

  static final List<String> quickResponses = [
    'Stock available. When can you pick up?',
    'We have limited stock. Would you like to place a pre-order?',
    'Price negotiable for bulk orders.',
    'Can we schedule a meeting to discuss?',
    'Unfortunately out of stock at the moment.',
    'Thank you for your interest. Will get back to you soon.',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: quickResponses.length,
      itemBuilder: (context, index) {
        final response = quickResponses[index];
        return ListTile(
          title: Text(response),
          onTap: () async {
            await DatabaseHelper.instance.respondToPurchaseRequest(
              purchaseRequestMessageId: purchaseRequest.id!,
              responseText: response,
              farmerId: farmer.id!,
              buyerId: buyer.id!,
            );
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Response sent!')),
            );
          },
        );
      },
    );
  }
}

// Usage:
// showModalBottomSheet(
//   context: context,
//   builder: (context) => QuickResponseBottomSheet(
//     farmer: currentFarmer,
//     buyer: selectedBuyer,
//     purchaseRequest: selectedRequest,
//   ),
// );
```

## Example: Response Analytics

```dart
class PurchaseRequestAnalytics {
  static Future<Map<String, dynamic>> getResponseMetrics(
    int farmerId,
  ) async {
    final allRequests = await DatabaseHelper.instance
        .getPurchaseRequestsForFarmer(farmerId);

    int responded = 0;
    int pending = 0;
    int totalRequests = allRequests.length;

    for (final request in allRequests) {
      final hasResponded = await DatabaseHelper.instance
          .hasRespondedToPurchaseRequest(
            request.senderId,
            farmerId,
            request.timestamp,
          );

      if (hasResponded) {
        responded++;
      } else {
        pending++;
      }
    }

    return {
      'totalRequests': totalRequests,
      'responded': responded,
      'pending': pending,
      'responseRate': totalRequests > 0 ? (responded / totalRequests) * 100 : 0,
    };
  }
}

// Usage:
// final metrics = await PurchaseRequestAnalytics.getResponseMetrics(farmerId);
// print('Total Requests: ${metrics['totalRequests']}');
// print('Response Rate: ${metrics['responseRate'].toStringAsFixed(1)}%');
```

## Example: Conversation History Widget

```dart
class ConversationHistoryWidget extends StatelessWidget {
  final int buyerId;
  final int farmerId;

  const ConversationHistoryWidget({
    required this.buyerId,
    required this.farmerId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Message>>(
      future: DatabaseHelper.instance.getBuyerFarmerConversation(
        buyerId,
        farmerId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final messages = snapshot.data ?? [];
        final purchaseRequests = messages
            .where((msg) => msg.isPurchaseRequest)
            .toList();
        final responses = messages
            .where((msg) => !msg.isPurchaseRequest)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Purchase Requests: ${purchaseRequests.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Total Responses: ${responses.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        message.isPurchaseRequest
                            ? '📋 Purchase Request'
                            : '💬 Response',
                      ),
                      subtitle: Text(
                        DateFormat('MMM d, h:mm a').format(message.timestamp),
                      ),
                      trailing: message.isRead
                          ? const Icon(Icons.done_all)
                          : const Icon(Icons.done),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
```

## Notes

These examples show how to:
1. ✅ Add response status indicators to UI
2. ✅ Create notification badges
3. ✅ Implement quick response templates
4. ✅ Track analytics
5. ✅ Display conversation history

Feel free to adapt these to your specific UI design and requirements!

