  import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:kaawa/data/user_data.dart';
import 'package:kaawa/data/cart_item.dart';
import 'package:kaawa/data/message_data.dart';
import 'package:kaawa/data/database_helper.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

class CartScreen extends StatefulWidget {
  final User buyer;
  final Map<int, CartItem> cartItems; // stock.id -> CartItem

  const CartScreen({
    super.key,
    required this.buyer,
    required this.cartItems,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Map<int, CartItem> _localCart;

  @override
  void initState() {
    super.initState();
    _localCart = Map.from(widget.cartItems);
  }

  double get _totalPrice => _localCart.values.fold(0, (sum, item) => sum + item.totalPrice);

  int get _totalItems => _localCart.length;

  Future<void> _launchPhone(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number not available')));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open dialer')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not initiate call: $e')));
    }
  }

  void _updateQuantity(int stockId, double newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        _localCart.remove(stockId);
      } else if (_localCart.containsKey(stockId)) {
        final item = _localCart[stockId]!;
        _localCart[stockId] = CartItem(
          id: item.id,
          buyerId: item.buyerId,
          stock: item.stock,
          farmer: item.farmer,
          quantityKg: newQuantity,
          addedAt: item.addedAt,
        );
      }
    });
  }

  void _removeItem(int stockId) {
    setState(() {
      _localCart.remove(stockId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item removed from cart')),
    );
  }

  Future<void> _sendPurchaseRequest(CartItem item) async {
    final theme = Theme.of(context);
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send Purchase Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sending to: ${item.farmer.fullName}',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item.stock.coffeeType}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text('${item.quantityKg} Kg', style: theme.textTheme.bodySmall),
                  Text('UGX ${item.stock.pricePerKg}/Kg', style: theme.textTheme.bodySmall),
                  const Divider(),
                  Text('Total: UGX ${item.totalPrice.toStringAsFixed(0)}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Add a message (optional):'),
            const SizedBox(height: 8),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., When can you deliver? Any discounts for bulk orders?',
                border: OutlineInputBorder(),
              ),
            ),
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
              await _submitPurchaseRequest(item, messageController.text);
              messageController.dispose();
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPurchaseRequest(CartItem item, String message) async {
    try {
      // Create JSON data for the purchase request
      final purchaseData = jsonEncode({
        'items': [
          {
            'stockId': item.stock.id,
            'coffeeType': item.stock.coffeeType,
            'quantityKg': item.quantityKg,
            'pricePerKg': item.stock.pricePerKg,
            'totalPrice': item.totalPrice,
          }
        ],
        'totalAmount': item.totalPrice,
      });

      final requestMessage = Message(
        senderId: widget.buyer.id!,
        receiverId: item.farmer.id!,
        text: message.isEmpty ? 'Purchase request for ${item.stock.coffeeType}' : message,
        timestamp: DateTime.now(),
        isPurchaseRequest: true,
        purchaseRequestData: purchaseData,
      );

      await DatabaseHelper.instance.insertMessage(requestMessage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase request sent to ${item.farmer.fullName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    }
  }

  void _showPurchaseDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Purchase Summary'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have ${_totalItems} item(s) in your cart:',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...List.generate(
                _localCart.length,
                (idx) {
                  final item = _localCart.values.elementAt(idx);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.stock.coffeeType,
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${item.quantityKg} Kg @ UGX ${item.stock.pricePerKg}/Kg',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'UGX ${item.totalPrice.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text('UGX ${_totalPrice.toStringAsFixed(0)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha((0.3 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You can now send this request to each farmer. They\'ll receive your order details and can respond with availability.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Continue Shopping'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ready to send purchase requests! Use the message buttons below.')),
              );
            },
            child: const Text('Send Requests'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: _localCart.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: theme.colorScheme.primary.withAlpha((0.5 * 255).round())),
                  const SizedBox(height: 16),
                  Text('Your cart is empty', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Browse and add items to get started', style: theme.textTheme.bodySmall),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _localCart.length,
                    itemBuilder: (context, index) {
                      final item = _localCart.values.elementAt(index);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product info with farmer
                              Row(
                                children: [
                                  AppAvatar(
                                    filePath: item.farmer.profilePicturePath,
                                    imageUrl: item.farmer.profilePicturePath,
                                    size: 48,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.stock.coffeeType, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                        Text(item.farmer.fullName, style: theme.textTheme.bodySmall),
                                        Text('UGX ${item.stock.pricePerKg}/Kg', style: theme.textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => _removeItem(item.stock.id!),
                                    tooltip: 'Remove item',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Quantity selector
                              Row(
                                children: [
                                  const Text('Quantity: '),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () => _updateQuantity(item.stock.id!, item.quantityKg - 1),
                                    iconSize: 20,
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                  ),
                                  Text('${item.quantityKg} Kg', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () => _updateQuantity(item.stock.id!, item.quantityKg + 1),
                                    iconSize: 20,
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                  ),
                                  const Spacer(),
                                  Text('Total: UGX ${item.totalPrice.toStringAsFixed(0)}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Contact farmer buttons
                               Row(
                                 mainAxisAlignment: MainAxisAlignment.end,
                                 children: [
                                   ElevatedButton.icon(
                                     onPressed: () => _launchPhone(item.farmer.phoneNumber),
                                     icon: const Icon(Icons.call, size: 18),
                                     label: const Text('Call'),
                                     style: ElevatedButton.styleFrom(
                                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                     ),
                                   ),
                                   const SizedBox(width: 8),
                                   ElevatedButton.icon(
                                     onPressed: () => _sendPurchaseRequest(item),
                                     icon: const Icon(Icons.send, size: 18),
                                     label: const Text('Send Request'),
                                     style: ElevatedButton.styleFrom(
                                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                       backgroundColor: theme.colorScheme.tertiary,
                                       foregroundColor: theme.colorScheme.onTertiary,
                                     ),
                                   ),
                                 ],
                               ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Bottom summary and checkout
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withAlpha((0.1 * 255).round()),
                        blurRadius: 8,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Items: $_totalItems', style: theme.textTheme.bodyMedium),
                          Text('Total: UGX ${_totalPrice.toStringAsFixed(0)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, _localCart),
                              child: const Text('Continue Shopping'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _showPurchaseDialog,
                              child: const Text('Review Order'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

