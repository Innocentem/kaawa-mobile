import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/coffee_stock_data.dart';
import 'package:kaawa_mobile/widgets/listing_carousel.dart';
import 'package:kaawa_mobile/widgets/app_avatar.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kaawa_mobile/data/database_helper.dart';

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

  @override
  void initState() {
    super.initState();
    photos = _parseImages(widget.stock.coffeePicturePath);
    _loadInterestedCount();
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
                      AppAvatar(filePath: widget.farmer?.profilePicturePath, imageUrl: widget.farmer?.profilePicturePath, size: 56),
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
                  child: Text(widget.stock.description),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
