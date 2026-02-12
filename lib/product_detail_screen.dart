import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/coffee_stock_data.dart';
import 'package:kaawa_mobile/widgets/listing_image.dart';
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
    // For now we only have one picture path; keep list for future
    photos = [widget.stock.coffeePicturePath, null, null, null];
  }

  void _previousImage() {
    setState(() {
      photoIndex = photoIndex > 0 ? photoIndex - 1 : 0;
    });
  }

  void _nextImage() {
    setState(() {
      photoIndex = photoIndex < photos.length - 1 ? photoIndex + 1 : photoIndex;
    });
  }

  Future<void> _loadInterestedCount() async {
    if (widget.stock.id != null) {
      final c = await DatabaseHelper.instance.getInterestCountForStock(widget.stock.id!);
      setState(() {
        _interestedCount = c;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imagePath = photos[photoIndex];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: FutureBuilder<void>(
        future: _loadInterestedCount(),
        builder: (context, snap) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 320.0,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: imagePath != null
                            ? ListingImage(path: imagePath, fit: BoxFit.cover)
                            : Container(color: theme.colorScheme.onSurface.withAlpha((0.04 * 255).round())),
                      ),
                      Positioned.fill(
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _previousImage,
                                behavior: HitTestBehavior.translucent,
                                child: Container(),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: _nextImage,
                                behavior: HitTestBehavior.translucent,
                                child: Container(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Card(
                          color: theme.colorScheme.surface.withAlpha((0.9 * 255).round()),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.favorite, color: theme.colorScheme.primary),
                          ),
                        ),
                      ),
                      // small dots
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(child: _SelectedPhoto(numberOfDots: photos.length, photoIndex: photoIndex, color: theme.colorScheme.primary)),
                      ),
                    ],
                  ),
                ),
              ),

              // sticky farmer contact area
              SliverPersistentHeader(
                pinned: true,
                delegate: _ContactHeaderDelegate(
                  minExtent: 72,
                  maxExtent: 72,
                  child: Container(
                    color: theme.colorScheme.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        if (widget.farmer != null) ...[
                          AppAvatar(filePath: widget.farmer!.profilePicturePath, imageUrl: widget.farmer!.profilePicturePath, size: 48),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.farmer?.fullName ?? 'Farmer', style: theme.textTheme.titleMedium),
                              Text('${_interestedCount} interested', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (widget.currentUser == null || widget.farmer == null) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(currentUser: widget.currentUser!, otherUser: widget.farmer!, coffeeStock: widget.stock),
                              ),
                            );
                          },
                          icon: const Icon(Icons.message),
                          label: const Text('Message'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.call),
                          onPressed: () async {
                            final tel = widget.farmer?.phoneNumber;
                            if (tel == null) return;
                            final uri = Uri(scheme: 'tel', path: tel);
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text('${widget.stock.quantity} kg available', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      Text('Description', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(widget.stock.description.isNotEmpty ? widget.stock.description : 'No description provided.', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: const SizedBox(height: 24),
              )
            ],
          );
        },
      ),
    );
  }
}

class _SelectedPhoto extends StatelessWidget {
  final int numberOfDots;
  final int photoIndex;
  final Color color;

  _SelectedPhoto({super.key, required this.numberOfDots, required this.photoIndex, required this.color});

  Widget _inactivePhoto() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Container(
        width: 8.0,
        height: 8.0,
        decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(4.0)),
      ),
    );
  }

  Widget _activePhoto() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Container(
        width: 10.0,
        height: 10.0,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5.0),
          boxShadow: [BoxShadow(color: Colors.grey.withAlpha((0.5 * 255).round()), blurRadius: 2.0)],
        ),
      ),
    );
  }

  List<Widget> buildDots() {
    List<Widget> dots = [];
    for (int i = 0; i < numberOfDots; ++i) {
      dots.add(i == photoIndex ? _activePhoto() : _inactivePhoto());
    }
    return dots;
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: buildDots()));
  }
}

class _ContactHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtent;
  final double maxExtent;
  final Widget child;

  _ContactHeaderDelegate({required this.minExtent, required this.maxExtent, required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _ContactHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.maxExtent != maxExtent || oldDelegate.minExtent != minExtent;
  }
}
