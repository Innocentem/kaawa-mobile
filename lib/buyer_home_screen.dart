import 'package:flutter/material.dart';
import 'package:kaawa_mobile/auth_service.dart';
import 'package:kaawa_mobile/chat_screen.dart';
import 'package:kaawa_mobile/conversations_screen.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/welcome_screen.dart';
import 'package:kaawa_mobile/profile_screen.dart';
import 'package:kaawa_mobile/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kaawa_mobile/data/coffee_stock_data.dart';
import 'package:kaawa_mobile/widgets/listing_carousel.dart';
import 'package:kaawa_mobile/widgets/compact_loader.dart';
import 'package:kaawa_mobile/widgets/app_avatar.dart';
import 'package:kaawa_mobile/product_detail_screen.dart';

class BuyerHomeScreen extends StatefulWidget {
  final User buyer;
  const BuyerHomeScreen({super.key, required this.buyer});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> with TickerProviderStateMixin {
  late Future<List<CoffeeStock>> _coffeeStockFuture;
  List<CoffeeStock> _allCoffeeStock = [];
  List<CoffeeStock> _filteredCoffeeStock = [];
  Set<int> _interestedStockIds = {};
  final Map<int, int> _interestCounts = {};
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _unreadMessageCount = 0;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _coffeeStockFuture = _getCoffeeStock();
    _searchController.addListener(_filterCoffeeStock);
    _getUnreadMessageCount();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getUnreadMessageCount() async {
    final count = await DatabaseHelper.instance.getUnreadMessageCount(widget.buyer.id!);
    setState(() {
      _unreadMessageCount = count;
    });
  }

  Future<List<CoffeeStock>> _getCoffeeStock() async {
    final stocks = await DatabaseHelper.instance.getAllCoffeeStock();
    // preload interest data for the current buyer
    _interestedStockIds = (await DatabaseHelper.instance.getInterestedStockIdsForBuyer(widget.buyer.id!)).toSet();
    // preload counts
    for (final s in stocks) {
      if (s.id != null) {
        final c = await DatabaseHelper.instance.getInterestCountForStock(s.id!);
        _interestCounts[s.id!] = c;
      }
    }
    return stocks;
  }

  void _filterCoffeeStock() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCoffeeStock = _allCoffeeStock.where((stock) {
        final coffeeTypeLower = stock.coffeeType.toLowerCase();
        return coffeeTypeLower.contains(query);
      }).toList();
    });
  }


  Future<void> _logout() async {
    await _authService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _launchPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open dialer')));
    }
  }

  List<String?> _parseImages(String? pathField) {
    if (pathField == null || pathField.trim().isEmpty) return [null];
    // allow comma-separated list of paths
    final parts = pathField.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return [null];
    return parts;
  }

  Future<void> _onCallPressed(int farmerId) async {
    try {
      final farmer = await DatabaseHelper.instance.getUserById(farmerId);
      if (farmer == null || farmer.phoneNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Farmer phone number not available')));
        return;
      }
      await _launchPhone(farmer.phoneNumber);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not initiate call: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        // ensure icons use the onPrimary color for contrast
        foregroundColor: theme.colorScheme.onPrimary,
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        actionsIconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        title: Semantics(
          label: 'Open profile',
          button: true,
          child: Tooltip(
            message: 'Open profile',
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(currentUser: widget.buyer, profileOwner: widget.buyer),
                  ),
                );
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Hero(tag: widget.buyer.id != null ? 'avatar-${widget.buyer.id}' : UniqueKey(), child: Material(type: MaterialType.transparency, child: AppAvatar(filePath: widget.buyer.profilePicturePath, imageUrl: widget.buyer.profilePicturePath, size: 40))),
                  if (_unreadMessageCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.onError, width: 1.5)),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Center(
                          child: Text(
                            _unreadMessageCount > 99 ? '99+' : '$_unreadMessageCount',
                            style: TextStyle(color: theme.colorScheme.onError, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Provider.of<ThemeNotifier>(context).themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
              color: IconTheme.of(context).color ?? theme.colorScheme.onSurface,
            ),
            onPressed: () {
              Provider.of<ThemeNotifier>(context, listen: false).toggleTheme();
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.message),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConversationsScreen(currentUser: widget.buyer),
                    ),
                  ).then((_) => _getUnreadMessageCount());
                },
              ),
              if (_unreadMessageCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_unreadMessageCount',
                      style: TextStyle(
                        color: theme.colorScheme.onError,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(currentUser: widget.buyer, profileOwner: widget.buyer),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Coffee', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Tap on a listing to view farmer details. Use the message icon to inquire or the cart icon to buy.',
              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: theme.textTheme.bodySmall?.color?.withAlpha((0.75 * 255).round())),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by coffee type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<CoffeeStock>>(
                future: _coffeeStockFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: const SizedBox(height: 200, child: Center(child: CompactLoader(size: 28, strokeWidth: 3.0, semanticsLabel: 'Loading coffee stock'))));
                  } else if (snapshot.hasError) {
                    return const Center(child: Text('Error loading coffee stock.'));
                  } else {
                    _allCoffeeStock = snapshot.data ?? [];
                    _filteredCoffeeStock = List.from(_allCoffeeStock);
                    return FadeTransition(
                      opacity: _animation,
                      child: _filteredCoffeeStock.isEmpty && _searchController.text.isNotEmpty
                          ? const Center(child: Text('No coffee stock found.'))
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.6,
                              ),
                              itemCount: _filteredCoffeeStock.length,
                              itemBuilder: (context, index) {
                                final stock = _filteredCoffeeStock[index];
                                final stockId = stock.id;
                                final liked = stockId != null && _interestedStockIds.contains(stockId);
                                final likeCount = stockId != null ? (_interestCounts[stockId] ?? 0) : 0;

                                final images = _parseImages(stock.coffeePicturePath);

                                return Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: InkWell(
                                    onTap: () async {
                                      final farmer = await DatabaseHelper.instance.getUserById(stock.farmerId);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProfileScreen(currentUser: widget.buyer, profileOwner: farmer!),
                                        ),
                                      );
                                    },
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          AspectRatio(
                                            aspectRatio: 1,
                                            child: ClipRRect(
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                              child: GestureDetector(
                                                onTap: () async {
                                                  // fetch farmer and open product detail (pass current buyer as currentUser)
                                                  final farmer = await DatabaseHelper.instance.getUserById(stock.farmerId);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => ProductDetailScreen(stock: stock, farmer: farmer, currentUser: widget.buyer),
                                                    ),
                                                  );
                                                },
                                                child: ListingCarousel(images: images, fit: BoxFit.cover),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(stock.coffeeType, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 4),
                                                Text('${stock.quantity} kg available', overflow: TextOverflow.ellipsis),
                                                Text('Price: UGX ${stock.pricePerKg}/kg', overflow: TextOverflow.ellipsis),
                                              ],
                                            ),
                                          ),
                                          // interest / like row
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? theme.colorScheme.error : (IconTheme.of(context).color ?? theme.textTheme.bodySmall?.color)),
                                                      onPressed: () async {
                                                        if (stockId == null) return;
                                                        if (liked) {
                                                          // remove interest
                                                          await DatabaseHelper.instance.removeInterest(stockId, widget.buyer.id!);
                                                          setState(() {
                                                            _interestedStockIds.remove(stockId);
                                                            _interestCounts[stockId] = (_interestCounts[stockId] ?? 1) - 1;
                                                          });
                                                        } else {
                                                          // add interest
                                                          await DatabaseHelper.instance.addInterest(stockId, widget.buyer.id!);
                                                          setState(() {
                                                            _interestedStockIds.add(stockId);
                                                            _interestCounts[stockId] = (_interestCounts[stockId] ?? 0) + 1;
                                                          });

                                                          // prompt to continue to chat
                                                          final consent = await showDialog<bool>(
                                                            context: context,
                                                            builder: (context) => AlertDialog(
                                                              title: const Text('Interested?'),
                                                              content: const Text('Would you like to start a chat with the owner to acquire this listing?'),
                                                              actions: [
                                                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                                                                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
                                                              ],
                                                            ),
                                                          );

                                                          if (consent == true) {
                                                            final farmer = await DatabaseHelper.instance.getUserById(stock.farmerId);
                                                            if (farmer != null) {
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder: (context) => ChatScreen(
                                                                    currentUser: widget.buyer,
                                                                    otherUser: farmer,
                                                                    coffeeStock: stock,
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        }
                                                      },
                                                    ),
                                                    Text('$likeCount'),
                                                  ],
                                                ),
                                                // contact owner quick action
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.call),
                                                      onPressed: () async {
                                                        _onCallPressed(stock.farmerId);
                                                      },
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.message),
                                                      onPressed: () async {
                                                        final farmer = await DatabaseHelper.instance.getUserById(stock.farmerId);
                                                        if (farmer != null) {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) => ChatScreen(
                                                                currentUser: widget.buyer,
                                                                otherUser: farmer,
                                                                coffeeStock: stock,
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                           const SizedBox(height: 8),
                                           Row(
                                             mainAxisAlignment: MainAxisAlignment.spaceAround,
                                             children: [
                                               IconButton(
                                                 icon: const Icon(Icons.shopping_cart),
                                                 onPressed: () async {
                                                   final farmer = await DatabaseHelper.instance.getUserById(stock.farmerId);
                                                   Navigator.push(
                                                     context,
                                                     MaterialPageRoute(
                                                       builder: (context) => ChatScreen(
                                                         currentUser: widget.buyer,
                                                         otherUser: farmer!,
                                                         initialMessage: 'I would like to buy your ${stock.coffeeType}.',
                                                         coffeeStock: stock,
                                                       ),
                                                     ),
                                                   );
                                                 },
                                               ),
                                             ],
                                           ),
                                         ],
                                       ),
                                     ),
                                   ),
                                 );
                               },
                            ),
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
}
