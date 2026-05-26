import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/chat_screen.dart';

// Assuming Message exists in user_data or another common place, otherwise using a local placeholder if needed
// Based on common patterns in this app.
import 'package:kaawa/data/message_data.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;

class PurchaseRequestsScreen extends StatefulWidget {
  final kaawa.User currentUser;
  const PurchaseRequestsScreen({super.key, required this.currentUser});

  @override
  State<PurchaseRequestsScreen> createState() => _PurchaseRequestsScreenState();
}

class _PurchaseRequestsScreenState extends State<PurchaseRequestsScreen> {
  late Future<List<Message>> _purchaseRequestsFuture;
  final Map<String, kaawa.User> _buyerCache = {};

  @override
  void initState() {
    super.initState();
    _refreshRequests();
  }

  void _refreshRequests() {
    setState(() {
      _purchaseRequestsFuture = SupabaseService.instance.getPurchaseRequestsForFarmer(widget.currentUser.id!);
    });
  }

  Future<kaawa.User?> _getBuyerInfo(String buyerId) async {
    if (_buyerCache.containsKey(buyerId)) return _buyerCache[buyerId];
    final user = await SupabaseService.instance.getProfile(buyerId);
    if (user != null) {
      _buyerCache[buyerId] = user;
    }
    return user;
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 12,
        bottom: 12,
      ),
      itemCount: 5,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Container(height: 100, color: Colors.grey[200]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.7),
              elevation: 0,
              foregroundColor: theme.colorScheme.onPrimary,
              title: Image.asset(
                'assets/icons/pngwing.png',
                height: 32,
                fit: BoxFit.contain,
              ),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshRequests(),
        edgeOffset: MediaQuery.of(context).padding.top + kToolbarHeight,
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Purchase Requests',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Message>>(
                future: _purchaseRequestsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildShimmerList();
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: 16),
                          const Text('Error loading purchase requests'),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _refreshRequests, child: const Text('Retry')),
                        ],
                      ),
                    );
                  } else {
                    final requests = snapshot.data ?? [];
                    if (requests.isEmpty) {
                      return ListView(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_cart_outlined, size: 64, color: theme.colorScheme.primary.withAlpha((0.5 * 255).round())),
                                const SizedBox(height: 16),
                                Text('No purchase requests yet', style: theme.textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Text('Buyers will send their purchase requests here', style: theme.textTheme.bodySmall),
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: _refreshRequests,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Refresh'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        return FutureBuilder<kaawa.User?>(
                          future: _getBuyerInfo(request.senderId),
                          builder: (context, buyerSnapshot) {
                            final buyer = buyerSnapshot.data;
                            if (buyerSnapshot.connectionState == ConnectionState.waiting && buyer == null) {
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                child: Container(height: 100),
                              );
                            }
                            return _buildPurchaseRequestCard(context, request, buyer, theme);
                          },
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseRequestCard(BuildContext context, Message request, kaawa.User? buyer, ThemeData theme) {
    final date = DateFormat.yMMMd().add_jm().format(request.timestamp);
    List<dynamic> items = [];
    if (request.purchaseRequestData != null) {
      try {
        final data = jsonDecode(request.purchaseRequestData!);
        items = data['items'] ?? [];
      } catch (e) {
        print('Error parsing purchase request data: $e');
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              if (buyer != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      currentUser: widget.currentUser,
                      otherUser: buyer,
                    ),
                  ),
                );
              }
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withAlpha((0.1 * 255).round()),
                        child: Text(
                          buyer?.fullName.substring(0, 1).toUpperCase() ?? '?',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              buyer?.fullName ?? 'Unknown Buyer',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              date,
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  const Divider(height: 24),
                  if (items.isNotEmpty) ...[
                    ...items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item['coffeeType']} (${item['quantityKg']} Kg)',
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                'UGX ${item['totalPrice']}',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    request.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (items.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _showCompleteSaleDialog(context, request, items, buyer),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Complete Sale'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.tertiary,
                      foregroundColor: theme.colorScheme.onTertiary,
                    ),
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    if (buyer != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            currentUser: widget.currentUser,
                            otherUser: buyer,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Reply'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCompleteSaleDialog(BuildContext context, Message request, List<dynamic> items, kaawa.User? buyer) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete Sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Marking this sale as complete will automatically deduct the quantity from your stock.'),
            const SizedBox(height: 16),
            ...items.map((item) => Text('• ${item['coffeeType']}: ${item['quantityKg']} Kg')),
            const SizedBox(height: 16),
            const Text('Are you sure you want to proceed?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _processCompletedSale(request, items, buyer);
            },
            child: const Text('Confirm Sale'),
          ),
        ],
      ),
    );
  }

  Future<void> _processCompletedSale(Message request, List<dynamic> items, kaawa.User? buyer) async {
    try {
      for (final item in items) {
        final stockId = item['stockId'];
        final quantity = (item['quantityKg'] as num).toDouble();
        if (stockId != null) {
          await SupabaseService.instance.updateCoffeeStockQuantity(stockId, quantity);
        }
      }

      // Update message status to trigger notification
      if (request.id != null) {
        final data = jsonDecode(request.purchaseRequestData ?? '{}');
        data['status'] = 'completed';
        await SupabaseService.instance.updateMessagePurchaseData(request.id!, jsonEncode(data));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale completed and stock updated!'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing sale: $e')),
        );
      }
    }
  }
}
