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
                  child: Text(widget.stock.description),
                ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
