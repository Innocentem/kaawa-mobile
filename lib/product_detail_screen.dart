import 'package:flutter/material.dart';
import 'package:kaawa/data/coffee_stock_data.dart';
import 'package:kaawa/widgets/listing_carousel.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/data/user_data.dart';
import 'package:kaawa/chat_screen.dart';
import 'package:kaawa/data/database_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kaawa/write_review_screen.dart';
import 'package:kaawa/profile_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final CoffeeStock stock;
  final User? farmer;
  final User? currentUser;

  const ProductDetailScreen({super.key, required this.stock, this.farmer, this.currentUser});

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int photoIndex = 0;
  late final List<String?> photos;
  int _interestedCount = 0;
  bool _reviewStatusLoaded = false;
  bool _alreadyReviewed = false;
  double _selectedQuantity = 1.0;

  @override
  void initState() {
    super.initState();
    photos = _parseImages(widget.stock.coffeePicturePath);
    _loadInterestedCount();
    _loadReviewStatus();
  }

  List<String?> _parseImages(String? pathField) {
    if (pathField == null || pathField.trim().isEmpty) return [null];
    final parts = pathField.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return [null];
    return parts;
  }

  Future<void> _loadInterestedCount() async {
    if (widget.stock.id != null) {
      final c = await DatabaseHelper.instance.getInterestCountForStock(widget.stock.id!);
      setState(() {
        _interestedCount = c;
      });
    }
  }

  Future<void> _loadReviewStatus() async {
    final currentUser = widget.currentUser;
    final farmer = widget.farmer;
    if (currentUser == null || farmer == null) return;
    if (currentUser.id == farmer.id) return;
    if (currentUser.userType == UserType.admin || farmer.userType == UserType.admin) return;
    final exists = await DatabaseHelper.instance.hasReviewByUser(currentUser.id!, farmer.id!);
    if (!mounted) return;
    setState(() {
      _alreadyReviewed = exists;
      _reviewStatusLoaded = true;
    });
  }

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

  Widget _buildSoldBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withAlpha((0.9 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'SOLD',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onError,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(
                  height: 320.0,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ListingCarousel(images: photos, fit: BoxFit.cover),
                      ),
                      if (widget.stock.isSold)
                        Positioned(
                          left: 12,
                          top: 12,
                          child: _buildSoldBadge(theme),
                        ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Card(
                          color: theme.colorScheme.surface.withAlpha((0.9 * 255).round()),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Icon(Icons.favorite, color: theme.colorScheme.error),
                                const SizedBox(width: 6),
                                Text('$_interestedCount')
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: widget.farmer == null || widget.currentUser == null
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileScreen(
                                      currentUser: widget.currentUser!,
                                      profileOwner: widget.farmer!,
                                    ),
                                  ),
                                );
                              },
                        child: AppAvatar(
                          filePath: widget.farmer?.profilePicturePath,
                          imageUrl: widget.farmer?.profilePicturePath,
                          size: 56,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.stock.coffeeType, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('UGX ${widget.stock.pricePerKg}/Kg', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.call),
                                  onPressed: () => _launchPhone(widget.farmer?.phoneNumber),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.message),
                                  onPressed: () {
                                    if (widget.currentUser != null && widget.farmer != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(currentUser: widget.currentUser!, otherUser: widget.farmer!, coffeeStock: widget.stock),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(widget.stock.description),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!widget.stock.isSold && widget.currentUser != null && widget.currentUser!.userType == UserType.buyer)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Available Quantity', style: theme.textTheme.bodySmall),
                                Text('${widget.stock.quantity} Kg', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Unit Price', style: theme.textTheme.bodySmall),
                                Text('UGX ${widget.stock.pricePerKg}/Kg', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Quantity selector
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Select Quantity (Kg)', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: _selectedQuantity > 1
                                        ? () => setState(() => _selectedQuantity = _selectedQuantity - 1)
                                        : null,
                                  ),
                                  Expanded(
                                    child: TextField(
                                      textAlign: TextAlign.center,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      controller: TextEditingController(text: _selectedQuantity.toStringAsFixed(1)),
                                      onChanged: (value) {
                                        final parsed = double.tryParse(value);
                                        if (parsed != null && parsed > 0 && parsed <= widget.stock.quantity) {
                                          setState(() => _selectedQuantity = parsed);
                                        }
                                      },
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        isDense: true,
                                        suffixText: 'Kg',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: _selectedQuantity < widget.stock.quantity
                                        ? () => setState(() => _selectedQuantity = _selectedQuantity + 1)
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Cost:', style: theme.textTheme.bodySmall),
                                  Text(
                                    'UGX ${(widget.stock.pricePerKg * _selectedQuantity).toStringAsFixed(0)}',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context, {
                                    'action': 'add_to_cart',
                                    'quantity': _selectedQuantity,
                                  });
                                },
                                icon: const Icon(Icons.shopping_cart),
                                label: const Text('Add to Cart'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  if (widget.currentUser != null && widget.farmer != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                          currentUser: widget.currentUser!,
                                          otherUser: widget.farmer!,
                                          coffeeStock: widget.stock,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.message),
                                label: const Text('Message'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                if (widget.currentUser != null && widget.farmer != null && widget.currentUser!.id != widget.farmer!.id && widget.currentUser!.userType != UserType.admin && widget.farmer!.userType != UserType.admin)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: ElevatedButton(
                      onPressed: !_reviewStatusLoaded || _alreadyReviewed
                          ? null
                          : () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WriteReviewScreen(
                                    reviewer: widget.currentUser!,
                                    reviewedUser: widget.farmer!,
                                  ),
                                ),
                              );
                              await _loadReviewStatus();
                            },
                      child: Text(_alreadyReviewed ? 'Review already submitted' : 'Write a Review'),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
