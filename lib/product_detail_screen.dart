import 'package:flutter/material.dart';
import 'package:kaawa/data/coffee_stock_data.dart';
import 'package:kaawa/widgets/listing_carousel.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/chat_screen.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/data/review_data.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kaawa/write_review_screen.dart';
import 'package:kaawa/profile_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final CoffeeStock stock;
  final kaawa.User? farmer;
  final kaawa.User? currentUser;
  final String? heroTag;

  const ProductDetailScreen({super.key, required this.stock, this.farmer, this.currentUser, this.heroTag});

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int photoIndex = 0;
  late final List<String?> photos;
  int _interestedCount = 0;
  bool _reviewStatusLoaded = false;
  bool _alreadyReviewed = false;
  bool _alreadyReviewedProduct = false;
  bool _isFavorite = false;
  bool _isInterested = false;
  bool _favoriteStatusLoaded = false;
  double _selectedQuantity = 1.0;
  kaawa.User? _farmer;
  double _averageRating = 0.0;
  List<Map<String, dynamic>> _productReviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _farmer = widget.farmer;
    photos = _parseImages(widget.stock.coffeePicturePath);
    _loadInterestedCount();
    _loadInterestStatus();
    _loadReviewStatus();
    _loadFavoriteStatus();
    _loadProductReviews();
    _subscribeToFarmerProfile();
  }

  Future<void> _loadProductReviews() async {
    if (widget.stock.id == null) return;
    try {
      final reviews = await SupabaseService.instance.getReviewsForProductWithReviewers(widget.stock.id!);
      final avg = await SupabaseService.instance.getAverageRatingForProduct(widget.stock.id!);
      if (mounted) {
        setState(() {
          _productReviews = reviews;
          _averageRating = avg;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      print('Error loading product reviews: $e');
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _loadFavoriteStatus() async {
    if (widget.currentUser == null || _farmer == null) return;
    if (widget.currentUser!.id == _farmer!.id) return;
    try {
      final favorites = await SupabaseService.instance.getFavorites(widget.currentUser!.id!);
      if (mounted) {
        setState(() {
          _isFavorite = favorites.any((u) => u.id == _farmer!.id);
          _favoriteStatusLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.currentUser == null || _farmer == null) return;
    try {
      if (_isFavorite) {
        await SupabaseService.instance.removeFavorite(widget.currentUser!.id!, _farmer!.id!);
      } else {
        await SupabaseService.instance.addFavorite(widget.currentUser!.id!, _farmer!.id!);
      }
      if (mounted) {
        setState(() {
          _isFavorite = !_isFavorite;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isFavorite ? 'Farmer added to favorites' : 'Farmer removed from favorites')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating favorite: $e')),
        );
      }
    }
  }

  void _subscribeToFarmerProfile() {
    if (widget.farmer?.id != null) {
      SupabaseService.instance.getProfileStream(widget.farmer!.id!).listen((updatedProfile) {
        if (mounted && updatedProfile != null) {
          setState(() {
            _farmer = updatedProfile;
          });
        }
      });
    }
  }

  List<String?> _parseImages(String? pathField) {
    if (pathField == null || pathField.trim().isEmpty) return [null];
    final parts = pathField.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return [null];
    return parts;
  }

  Future<void> _loadInterestedCount() async {
    if (widget.stock.id != null) {
      final c = await SupabaseService.instance.getInterestCountForStock(widget.stock.id!);
      if (mounted) {
        setState(() {
          _interestedCount = c;
        });
      }
    }
  }

  Future<void> _loadInterestStatus() async {
    if (widget.stock.id != null && widget.currentUser != null) {
      final interested = await SupabaseService.instance.isInterested(widget.stock.id!, widget.currentUser!.id!);
      if (mounted) {
        setState(() {
          _isInterested = interested;
        });
      }
    }
  }

  Future<void> _toggleInterest() async {
    if (widget.stock.id == null || widget.currentUser == null) return;
    if (widget.currentUser!.id == widget.stock.farmerId) return;

    try {
      await SupabaseService.instance.toggleInterest(widget.stock.id!, widget.currentUser!.id!);
      if (mounted) {
        setState(() {
          _isInterested = !_isInterested;
          if (_isInterested) {
            _interestedCount++;
          } else {
            _interestedCount--;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isInterested ? 'Interest recorded' : 'Interest removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating interest: $e')),
        );
      }
    }
  }

  Future<void> _loadReviewStatus() async {
    final currentUser = widget.currentUser;
    final farmer = widget.farmer;
    if (currentUser == null) return;

    final userId = currentUser.id!;
    
    bool farmerReviewed = false;
    if (farmer != null && userId != farmer.id && currentUser.userType != kaawa.UserType.admin && farmer.userType != kaawa.UserType.admin) {
      farmerReviewed = await SupabaseService.instance.hasReviewByUser(userId, farmer.id!);
    }

    bool productReviewed = false;
    if (widget.stock.id != null) {
      productReviewed = await SupabaseService.instance.hasReviewForProduct(userId, widget.stock.id!);
    }

    if (!mounted) return;
    setState(() {
      _alreadyReviewed = farmerReviewed;
      _alreadyReviewedProduct = productReviewed;
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
        widget.stock.quantityRemaining <= 0 ? 'SOLD OUT' : 'SOLD',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onError,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildRatingStars(double rating, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star_rounded, color: Colors.amber, size: size);
        } else if (index < rating && rating % 1 != 0) {
          return Icon(Icons.star_half_rounded, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_outline_rounded, color: Colors.amber, size: size);
        }
      }),
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
        actions: [
          if (widget.currentUser != null && _farmer != null && widget.currentUser!.id != _farmer!.id && _favoriteStatusLoaded)
            IconButton(
              icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : null),
              onPressed: _toggleFavorite,
            ),
        ],
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
                        child: widget.heroTag != null
                            ? Hero(
                                tag: widget.heroTag!,
                                child: ListingCarousel(images: photos, fit: BoxFit.cover),
                              )
                            : ListingCarousel(images: photos, fit: BoxFit.cover),
                      ),
                      if (widget.stock.isSold || widget.stock.quantityRemaining <= 0)
                        Positioned(
                          left: 12,
                          top: 12,
                          child: _buildSoldBadge(theme),
                        ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: GestureDetector(
                          onTap: (widget.currentUser == null || widget.currentUser!.id == widget.stock.farmerId)
                              ? null
                              : _toggleInterest,
                          child: Card(
                            color: theme.colorScheme.surface.withAlpha((0.9 * 255).round()),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    _isInterested ? Icons.favorite : Icons.favorite_border,
                                    color: theme.colorScheme.error,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('$_interestedCount')
                                ],
                              ),
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
                        onTap: _farmer == null || widget.currentUser == null
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileScreen(
                                      currentUser: widget.currentUser!,
                                      profileOwner: _farmer!,
                                    ),
                                  ),
                                );
                              },
                        child: AppAvatar(
                          filePath: _farmer?.profilePicturePath,
                          imageUrl: _farmer?.profilePicturePath,
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
                            Row(
                              children: [
                                _buildRatingStars(_averageRating),
                                const SizedBox(width: 8),
                                Text(
                                  _averageRating > 0 ? _averageRating.toStringAsFixed(1) : 'No reviews',
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('UGX ${widget.stock.pricePerKg}/Kg', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.call),
                                  onPressed: () => _launchPhone(_farmer?.phoneNumber),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.message),
                                  onPressed: () {
                                    if (widget.currentUser != null && _farmer != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(currentUser: widget.currentUser!, otherUser: _farmer!, coffeeStock: widget.stock),
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
                if (!widget.stock.isSold && widget.stock.quantityRemaining > 0 && widget.currentUser != null && widget.currentUser!.userType == kaawa.UserType.buyer)
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
                                Text('${widget.stock.quantityRemaining} Kg', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                                        if (parsed != null && parsed > 0 && parsed <= widget.stock.quantityRemaining) {
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
                                    onPressed: _selectedQuantity < widget.stock.quantityRemaining
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
                                  if (widget.currentUser != null && _farmer != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                          currentUser: widget.currentUser!,
                                          otherUser: _farmer!,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product Reviews',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingReviews)
                        const Center(child: CircularProgressIndicator())
                      else if (_productReviews.isEmpty)
                        Text('No reviews for this product yet.', style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: theme.hintColor))
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _productReviews.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final entry = _productReviews[index];
                            final review = entry['review'] as Review;
                            final reviewer = entry['reviewer'] as kaawa.User?;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (reviewer != null) ...[
                                      AppAvatar(
                                        filePath: reviewer.profilePicturePath,
                                        imageUrl: reviewer.profilePicturePath,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        reviewer.fullName,
                                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ] else
                                      Text(
                                        'Anonymous',
                                        style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                                      ),
                                    const Spacer(),
                                    if (review.timestamp != null)
                                      Text(
                                        '${review.timestamp!.day}/${review.timestamp!.month}/${review.timestamp!.year}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildRatingStars(review.rating, size: 14),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(review.comment, style: theme.textTheme.bodyMedium),
                              ],
                            );
                          },
                        ),
                      if (widget.currentUser != null && widget.currentUser!.userType == kaawa.UserType.buyer)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: OutlinedButton.icon(
                            onPressed: _alreadyReviewedProduct
                                ? null
                                : () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => WriteReviewScreen(
                                          reviewer: widget.currentUser!,
                                          coffeeStock: widget.stock,
                                          reviewedUser: _farmer,
                                        ),
                                      ),
                                    );
                                    _loadProductReviews();
                                    _loadReviewStatus();
                                  },
                            icon: const Icon(Icons.rate_review_outlined),
                            label: Text(_alreadyReviewedProduct ? 'Product Reviewed' : 'Review this Product'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.currentUser != null && _farmer != null && widget.currentUser!.id != _farmer!.id && widget.currentUser!.userType != kaawa.UserType.admin && _farmer!.userType != kaawa.UserType.admin)
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
                                    reviewedUser: _farmer!,
                                  ),
                                ),
                              );
                              await _loadReviewStatus();
                            },
                      child: Text(_alreadyReviewed ? 'Farmer already reviewed' : 'Review Farmer'),
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
