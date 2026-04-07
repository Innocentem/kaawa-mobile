import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kaawa/auth_service.dart';
import 'package:kaawa/chat_screen.dart';
import 'package:kaawa/conversations_screen.dart';
import 'package:kaawa/data/user_data.dart';
import 'package:kaawa/data/database_helper.dart';
import 'package:kaawa/welcome_screen.dart';
import 'package:kaawa/profile_screen.dart';
import 'package:kaawa/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:kaawa/data/coffee_stock_data.dart';
import 'package:kaawa/data/cart_item.dart';
import 'package:kaawa/cart_screen.dart';
import 'package:kaawa/widgets/listing_carousel.dart';
import 'package:kaawa/widgets/compact_loader.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/product_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kaawa/review_notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BuyerHomeScreen extends StatefulWidget {
  final User buyer;
  const BuyerHomeScreen({super.key, required this.buyer});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late Future<List<CoffeeStock>> _coffeeStockFuture;
  List<CoffeeStock> _allCoffeeStock = [];
  List<CoffeeStock> _filteredCoffeeStock = [];
  Set<int> _interestedStockIds = {};
  final Map<int, int> _interestCounts = {};
  final Map<int, User> _farmerCache = {};
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _unreadMessageCount = 0;
  int _unreadReviewCount = 0;
  final AuthService _authService = AuthService();
  late User _currentBuyer;

  // Cart state
  Map<int, CartItem> _cart = {}; // stock.id -> CartItem
  int _cartItemCount = 0;

  final LayerLink _profileLink = LayerLink();
  final LayerLink _messageLink = LayerLink();
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _messageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentBuyer = widget.buyer;
    _checkSuspensionAndLogout();
    _coffeeStockFuture = _getCoffeeStock();
    _searchController.addListener(_filterCoffeeStock);
    _getUnreadMessageCount();
    _getUnreadReviewCount();
    _loadCartFromPrefs();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();

    _scheduleOnboardingGuides();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    // Do not clear cart on dispose; cart is persisted across sessions unless user clears it
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSuspensionAndLogout();
    }
  }

  Future<void> _checkSuspensionAndLogout() async {
    final current = await DatabaseHelper.instance.getUserById(widget.buyer.id!);
    if (current == null || !current.isSuspended) return;
    await _authService.logout();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final remaining = current.suspensionRemainingText;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Account suspended'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your account is suspended until ${current.suspendedUntil!.toLocal()}.'),
              if (remaining != null) ...[
                const SizedBox(height: 6),
                Text('Time left: $remaining'),
              ],
              const SizedBox(height: 8),
              if (current.suspensionReason != null && current.suspensionReason!.isNotEmpty)
                Text('Reason: ${current.suspensionReason}'),
              const SizedBox(height: 12),
              const Text('If you believe this is a mistake, contact admin.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    });
  }

  Future<void> _getUnreadMessageCount() async {
    final count = await DatabaseHelper.instance.getUnreadMessageCount(widget.buyer.id!);
    setState(() {
      _unreadMessageCount = count;
    });
  }

  Future<void> _getUnreadReviewCount() async {
    final count = await DatabaseHelper.instance.getUnreadReviewNotificationCount(widget.buyer.id!);
    if (!mounted) return;
    setState(() => _unreadReviewCount = count);
  }

  Future<List<CoffeeStock>> _getCoffeeStock() async {
    final stocks = await DatabaseHelper.instance.getAllCoffeeStock();
    // preload interest data for the current buyer
    _interestedStockIds = (await DatabaseHelper.instance.getInterestedStockIdsForBuyer(widget.buyer.id!)).toSet();
    // preload counts + farmer cache
    for (final s in stocks) {
      if (s.id != null) {
        final c = await DatabaseHelper.instance.getInterestCountForStock(s.id!);
        _interestCounts[s.id!] = c;
      }
      final farmer = await DatabaseHelper.instance.getUserById(s.farmerId);
      if (farmer != null) {
        _farmerCache[s.farmerId] = farmer;
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

  Future<void> _handleLogoutRequest() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Do you really want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Logout')),
        ],
      ),
    );

    if (shouldLogout != true) return;
    // Do NOT clear the cart on logout. Cart is persisted across sessions so user can track progress.
    // Pending requests and unsent requests remain in the cart until the user clears them.
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    await _handleLogoutRequest();
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

  void _addToCart(CoffeeStock stock, User farmer, double quantity) {
    if (stock.id == null) return;
    final sid = stock.id!;
    setState(() {
      if (_cart.containsKey(sid)) {
        // merge quantities instead of creating duplicate entries
        final existing = _cart[sid]!;
        final newQty = existing.quantityKg + quantity;
        _cart[sid] = CartItem(
          id: existing.id,
          buyerId: existing.buyerId,
          stock: existing.stock,
          farmer: existing.farmer,
          quantityKg: newQty,
          addedAt: existing.addedAt,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated ${stock.coffeeType} to ${newQty} Kg in cart')));
      } else {
        _cart[sid] = CartItem(
          id: DateTime.now().millisecondsSinceEpoch,
          buyerId: widget.buyer.id!,
          stock: stock,
          farmer: farmer,
          quantityKg: quantity,
          addedAt: DateTime.now(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${quantity} Kg of ${stock.coffeeType} to cart'),
            action: SnackBarAction(
              label: 'View Cart',
              onPressed: () async {
                final result = await Navigator.push<Map<int, CartItem>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CartScreen(buyer: widget.buyer, cartItems: _cart),
                  ),
                );
                if (result != null) {
                  setState(() {
                    _cart = result;
                    _cartItemCount = _cart.length;
                  });
                  _saveCartToPrefs();
                }
              },
            ),
          ),
        );
      }

      _cartItemCount = _cart.length;
      _saveCartToPrefs();
    });
  }

  Future<void> _saveCartToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = _cart.values.map((c) => {
            'stockId': c.stock.id,
            'farmerId': c.farmer.id,
            'quantityKg': c.quantityKg,
            'addedAt': c.addedAt.toIso8601String(),
          }).toList();
      await prefs.setString('cart_${widget.buyer.id}', jsonEncode(items));
    } catch (_) {
      // ignore persistence errors
    }
  }

  Future<void> _loadCartFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('cart_${widget.buyer.id}');
      if (s == null || s.isEmpty) return;
      final List<dynamic> list = jsonDecode(s);
      final Map<int, CartItem> loaded = {};
      for (final entry in list) {
        final stockId = (entry['stockId'] as num?)?.toInt();
        final farmerId = (entry['farmerId'] as num?)?.toInt();
        final quantity = (entry['quantityKg'] as num?)?.toDouble() ?? 0.0;
        final addedAtStr = entry['addedAt'] as String?;
        if (stockId == null || farmerId == null) continue;
        final stock = await DatabaseHelper.instance.getCoffeeStockById(stockId);
        final farmer = await DatabaseHelper.instance.getUserById(farmerId);
        if (stock == null || farmer == null) continue;
        loaded[stockId] = CartItem(
          id: DateTime.now().millisecondsSinceEpoch,
          buyerId: widget.buyer.id!,
          stock: stock,
          farmer: farmer,
          quantityKg: quantity,
          addedAt: addedAtStr != null ? DateTime.parse(addedAtStr) : DateTime.now(),
        );
      }
      if (!mounted) return;
      setState(() {
        _cart = loaded;
        _cartItemCount = _cart.length;
      });
    } catch (_) {
      // ignore
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

  Future<void> _refreshCurrentBuyer() async {
    final refreshed = await DatabaseHelper.instance.getUserById(widget.buyer.id!);
    if (refreshed == null || !mounted) return;
    setState(() {
      _currentBuyer = refreshed;
    });
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(currentUser: _currentBuyer, profileOwner: _currentBuyer),
      ),
    );
    await _refreshCurrentBuyer();
  }

  Future<void> _scheduleOnboardingGuides() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'guide_buyer_home_v1_${widget.buyer.id}';
    if (prefs.getBool(key) == true) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _showCoachMark(
        link: _profileLink,
        targetKey: _profileKey,
        title: 'Update your profile',
        message: 'Tap your avatar to edit your profile and photo.',
      );
      if (!mounted) return;
      await _showCoachMark(
        link: _messageLink,
        targetKey: _messageKey,
        title: 'Messages',
        message: 'Check your chats and reply to farmers here.',
      );
      await prefs.setBool(key, true);
    });
  }

  Future<void> _showCoachMark({
    required LayerLink link,
    required GlobalKey targetKey,
    required String title,
    required String message,
  }) async {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final screenHeight = overlayBox?.size.height ?? MediaQuery.of(context).size.height;
    final targetOffset = (renderBox != null && overlayBox != null)
        ? renderBox.localToGlobal(Offset.zero, ancestor: overlayBox)
        : Offset.zero;
    final targetHeight = renderBox?.size.height ?? 0.0;
    const tooltipHeightEstimate = 140.0;
    final spaceAbove = targetOffset.dy;
    final spaceBelow = screenHeight - (targetOffset.dy + targetHeight);
    final showAbove = spaceAbove >= tooltipHeightEstimate || spaceAbove > spaceBelow;

    final completer = Completer<void>();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        return GestureDetector(
          onTap: () {
            entry.remove();
            completer.complete();
          },
          child: Material(
            color: Colors.black54,
            child: SafeArea(
              child: Stack(
                children: [
                  CompositedTransformFollower(
                    link: link,
                    targetAnchor: showAbove ? Alignment.topCenter : Alignment.bottomCenter,
                    followerAnchor: showAbove ? Alignment.bottomCenter : Alignment.topCenter,
                    offset: showAbove ? const Offset(0, -8) : const Offset(0, 8),
                    showWhenUnlinked: false,
                    child: Material(
                      color: Colors.transparent,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Card(
                          color: theme.colorScheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(message, style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 8),
                                Text('Tap anywhere to continue', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    await completer.future;
  }

  Widget _buildSwipeIndicator(int count, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (index) => Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withAlpha((0.75 * 255).round()),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildSoldBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withAlpha((0.9 * 255).round()),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'SOLD',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onError,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        await _handleLogoutRequest();
        return false;
      },
      child: Scaffold(
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
              child: CompositedTransformTarget(
                link: _profileLink,
                child: InkWell(
                  key: _profileKey,
                  borderRadius: BorderRadius.circular(24),
                  onTap: _openProfile,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Hero(
                        tag: _currentBuyer.id != null ? 'avatar-${_currentBuyer.id}' : UniqueKey(),
                        child: Material(
                          type: MaterialType.transparency,
                          child: AppAvatar(
                            filePath: _currentBuyer.profilePicturePath,
                            imageUrl: _currentBuyer.profilePicturePath,
                            size: 40,
                          ),
                        ),
                      ),
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
          ),
           actions: [
             IconButton(
               icon: Icon(
                 Provider.of<ThemeNotifier>(context).themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                 color: theme.colorScheme.onPrimary,
               ),
               onPressed: () {
                 Provider.of<ThemeNotifier>(context, listen: false).toggleTheme();
               },
             ),
             Stack(
               children: [
                 IconButton(
                   icon: const Icon(Icons.shopping_cart),
                   tooltip: 'Shopping Cart',
                   onPressed: () async {
                     final result = await Navigator.push<Map<int, CartItem>>(
                       context,
                       MaterialPageRoute(
                         builder: (context) => CartScreen(buyer: widget.buyer, cartItems: _cart),
                       ),
                     );
                     if (result != null) {
                       setState(() {
                         _cart = result;
                         _cartItemCount = _cart.length;
                       });
                     }
                   },
                 ),
                 if (_cartItemCount > 0)
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
                         _cartItemCount > 99 ? '99+' : '$_cartItemCount',
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
             Stack(
               children: [
                 CompositedTransformTarget(
                   link: _messageLink,
                   child: IconButton(
                     key: _messageKey,
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
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.star_rate),
                  tooltip: 'Reviews',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReviewNotificationsScreen(currentUser: _currentBuyer),
                      ),
                    );
                    await _getUnreadReviewCount();
                  },
                ),
                if (_unreadReviewCount > 0)
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
                        '$_unreadReviewCount',
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
              onPressed: _openProfile,
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
              Row(
                children: [
                  Text('Available Coffee', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Tap a listing to view farmer details. Use message or cart to inquire/buy.',
                    child: Icon(Icons.info_outline, size: 18, color: IconTheme.of(context).color ?? theme.colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                                    color: stock.isSold ? theme.colorScheme.error.withAlpha((0.08 * 255).round()) : null,
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
                                                child: Stack(
                                                  children: [
                                                    Positioned.fill(
                                                      child: GestureDetector(
                                        onTap: () async {
                                                           // fetch farmer and open product detail (pass current buyer as currentUser)
                                                           final farmer = await DatabaseHelper.instance.getUserById(stock.farmerId);
                                                           final result = await Navigator.push<Map<String, dynamic>>(
                                                             context,
                                                             MaterialPageRoute(
                                                               builder: (context) => ProductDetailScreen(stock: stock, farmer: farmer, currentUser: widget.buyer),
                                                             ),
                                                           );

                                                           // Handle cart addition
                                                           if (result != null && result['action'] == 'add_to_cart' && farmer != null) {
                                                             final quantity = result['quantity'] as double;
                                                             _addToCart(stock, farmer, quantity);
                                                           }
                                                         },
                                                        child: ListingCarousel(images: images, fit: BoxFit.cover),
                                                      ),
                                                    ),
                                                    if (stock.isSold)
                                                      Positioned(
                                                        top: 8,
                                                        left: 8,
                                                        child: _buildSoldBadge(theme),
                                                      ),
                                                    if (images.length > 1)
                                                      Positioned(
                                                        left: 0,
                                                        right: 0,
                                                        bottom: 6,
                                                        child: Center(
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: theme.colorScheme.surface.withAlpha((0.7 * 255).round()),
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: _buildSwipeIndicator(images.length, theme),
                                                          ),
                                                        ),
                                                      ),
                                                    Positioned(
                                                      left: 8,
                                                      bottom: 8,
                                                      child: Material(
                                                        color: Colors.transparent,
                                                        child: InkWell(
                                                          borderRadius: BorderRadius.circular(18),
                                                          onTap: () {
                                                            final farmer = _farmerCache[stock.farmerId];
                                                            if (farmer == null) return;
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) => ProfileScreen(currentUser: widget.buyer, profileOwner: farmer),
                                                              ),
                                                            );
                                                          },
                                                          child: AppAvatar(
                                                            filePath: _farmerCache[stock.farmerId]?.profilePicturePath,
                                                            imageUrl: _farmerCache[stock.farmerId]?.profilePicturePath,
                                                            size: 36,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
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
                                                  if (stock.isSold)
                                                    Text('SOLD', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
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
                                                        onPressed: stock.isSold
                                                            ? null
                                                            : () async {
                                                                _onCallPressed(stock.farmerId);
                                                              },
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.message),
                                                        onPressed: stock.isSold
                                                            ? null
                                                            : () async {
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
                                                   onPressed: stock.isSold
                                                       ? null
                                                       : () async {
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
      ),
    );
  }
}
