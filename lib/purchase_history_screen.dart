import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/data/message_data.dart';
import 'package:kaawa/write_review_screen.dart';
import 'package:kaawa/chat_screen.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  final kaawa.User currentUser;
  const PurchaseHistoryScreen({super.key, required this.currentUser});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  late Stream<List<Message>> _purchaseHistoryStream;
  final Map<String, kaawa.User> _farmerCache = {};

  @override
  void initState() {
    super.initState();
    _purchaseHistoryStream = SupabaseService.instance.getPurchaseHistoryStream(widget.currentUser.id!);
  }

  Future<kaawa.User?> _getFarmerInfo(String farmerId) async {
    if (_farmerCache.containsKey(farmerId)) return _farmerCache[farmerId];
    final user = await SupabaseService.instance.getProfile(farmerId);
    if (user != null) {
      _farmerCache[farmerId] = user;
    }
    return user;
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
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.9),
              elevation: 0,
              foregroundColor: theme.colorScheme.onPrimary,
              iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
              title: const Text('My Purchases', style: TextStyle(fontWeight: FontWeight.bold)),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _purchaseHistoryStream = SupabaseService.instance.getPurchaseHistoryStream(widget.currentUser.id!);
          });
        },
        edgeOffset: MediaQuery.of(context).padding.top + kToolbarHeight,
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 16),
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _purchaseHistoryStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: 16),
                          const Text('Error loading purchase history'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _purchaseHistoryStream = SupabaseService.instance.getPurchaseHistoryStream(widget.currentUser.id!);
                                });
                              },
                              child: const Text('Retry')),
                        ],
                      ),
                    );
                  } else {
                    final purchases = snapshot.data ?? [];
                    if (purchases.isEmpty) {
                      return ListView(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_bag_outlined, size: 64, color: theme.colorScheme.primary.withAlpha(128)),
                                const SizedBox(height: 16),
                                Text('No purchases yet', style: theme.textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Text('Your completed purchases will appear here', style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: purchases.length,
                      itemBuilder: (context, index) {
                        final purchase = purchases[index];
                        return FutureBuilder<kaawa.User?>(
                          future: _getFarmerInfo(purchase.receiverId),
                          builder: (context, farmerSnapshot) {
                            final farmer = farmerSnapshot.data;
                            return _buildPurchaseCard(context, purchase, farmer, theme);
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

  Widget _buildPurchaseCard(BuildContext context, Message purchase, kaawa.User? farmer, ThemeData theme) {
    final date = DateFormat.yMMMd().format(purchase.timestamp);
    List<dynamic> items = [];
    String status = 'Pending';
    if (purchase.purchaseRequestData != null) {
      try {
        final data = jsonDecode(purchase.purchaseRequestData!);
        items = data['items'] ?? [];
        if (data['status'] == 'completed') {
          status = 'Completed';
        }
      } catch (e) {
        print('Error parsing purchase data: $e');
      }
    }

    final isCompleted = status == 'Completed';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green.withAlpha(30) : Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isCompleted ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withAlpha(25),
                  child: Text(
                    farmer?.fullName.substring(0, 1).toUpperCase() ?? '?',
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    farmer?.fullName ?? 'Unknown Farmer',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (items.isNotEmpty) ...[
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${item['coffeeType']} (${item['quantityKg']} Kg)'),
                        Text('UGX ${item['totalPrice']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
              const Divider(height: 24),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isCompleted)
                  OutlinedButton.icon(
                    onPressed: () {
                      if (farmer != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WriteReviewScreen(
                              reviewer: widget.currentUser,
                              reviewedUser: farmer,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.star_border, size: 18),
                    label: const Text('Rate Farmer'),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    if (farmer != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            currentUser: widget.currentUser,
                            otherUser: farmer,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Message'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
