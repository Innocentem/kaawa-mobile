import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kaawa/auth_service.dart';
import 'package:kaawa/chat_screen.dart';
import 'package:kaawa/conversations_screen.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/data/database_helper.dart';
import 'package:kaawa/welcome_screen.dart';
import 'package:kaawa/profile_screen.dart';
import 'package:kaawa/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:kaawa/data/coffee_stock_data.dart';
import 'package:kaawa/data/cart_item.dart';
import 'package:kaawa/cart_screen.dart';
import 'package:kaawa/favorites_screen.dart';
import 'package:kaawa/widgets/listing_carousel.dart';
import 'package:kaawa/widgets/compact_loader.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/product_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kaawa/notifications_screen.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaawa/user_selection_screen.dart';
import 'package:kaawa/utils/date_utils.dart';
import 'package:kaawa/purchase_history_screen.dart';

class BuyerHomeScreen extends StatefulWidget {
  final kaawa.User buyer;
  const BuyerHomeScreen({super.key, required this.buyer});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late Stream<List<CoffeeStock>> _coffeeStockStream;
  List<CoffeeStock> _allCoffeeStock = [];
  List<CoffeeStock> _filteredCoffeeStock = [];
  Set<String> _interestedStockIds = {};
  final Map<String, int> _interestCounts = {};
  final Map<String, kaawa.User> _farmerCache = {};
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _unreadMessageCount = 0;
  int _unreadNotificationCount = 0;
  StreamSubscription<int>? _messageSubscription;
  StreamSubscription<int>? _notificationSubscription;
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService.instance;
  late kaawa.User _currentBuyer;

  // Cart state
  Map<String, CartItem> _cart = {}; // stock.id -> CartItem
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
    _coffeeStockStream = _supabaseService.getAllCoffeeStockStream();
    _searchController.addListener(_filterCoffeeStock);
    _getUnreadNotificationCount();
    _loadCartFromPrefs();

    _messageSubscription = _supabaseService.getUnreadMessageCountStream(widget.buyer.id!).listen((count) {
      if (mounted) {
        setState(() {
          _unreadMessageCount = count;
        });
      }
    });

    _notificationSubscription = _supabaseService.getUnreadNotificationCountStream(widget.buyer.id!).listen((count) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    });

    _authService.currentUserDataStream.listen((user) {
      if (user != null && mounted) {
        if (user.isSuspended) {
          _checkSuspensionAndLogout(user);
        } else {
          setState(() {
            _currentBuyer = user;
          });
        }
      }
    });

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
    _messageSubscription?.cancel();
    _notificationSubscription?.cancel();
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

  Future<void> _checkSuspensionAndLogout([kaawa.User? user]) async {
    final current = user ?? await _supabaseService.getProfile(widget.buyer.id!);
    if (current == null || !current.isSuspended) return;
    
    // Check if we are already showing the dialog to avoid duplicates
    if (!mounted) return;
    
    await _authService.logout();
    
    if (!mounted) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final remaining = current.suspensionRemainingText;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
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
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  (route) => false,
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _getUnreadMessageCount() async {
    final count = await _supabaseService.getUnreadMessageCount(widget.buyer.id!);
    setState(() {
      _unreadMessageCount = count;
    });
  }

  Future<void> _getUnreadNotificationCount() async {
    final count = await _supabaseService.getUnreadNotificationCount(widget.buyer.id!);
    if (!mounted) return;
    setState(() => _unreadNotificationCount = count);
  }

  Future<List<CoffeeStock>> _getCoffeeStock() async {
    final stocks = await _supabaseService.getAllCoffeeStock();
    // preload interest data for the current buyer
    _interestedStockIds = (await _supabaseService.getInterestedStockIdsForBuyer(widget.buyer.id!)).toSet();
    // preload counts + farmer cache
    for (final s in stocks) {
      if (s.id != null) {
        final c = await _supabaseService.getInterestCountForStock(s.id!);
        _interestCounts[s.id!] = c;
      }
      final farmer = await _supabaseService.getProfile(s.farmerId);
      if (farmer != null) {
        _farmerCache[s.farmerId] = farmer;
      }
    }
    return stocks;
  }

  void _filterCoffeeStock() {
    final query = _searchController.text.toLowerCase();
    final filtered = _allCoffeeStock.where((stock) {
      final coffeeTypeLower = stock.coffeeType.toLowerCase();
      return coffeeTypeLower.contains(query);
    }).toList();
    
    if (filtered.length != _filteredCoffeeStock.length || !filtered.every((s) => _filteredCoffeeStock.contains(s))) {
       setState(() {
        _filteredCoffeeStock = filtered;
      });
    }
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

  void _addToCart(CoffeeStock stock, kaawa.User farmer, double quantity) {
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
          id: DateTime.now().millisecondsSinceEpoch.toString(),
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
                final result = await Navigator.push<Map<String, CartItem>>(
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
      final Map<String, CartItem> loaded = {};
      for (final entry in list) {
        final stockId = entry['stockId'] as String?;
        final farmerId = entry['farmerId'] as String?;
        final quantity = (entry['quantityKg'] as num?)?.toDouble() ?? 0.0;
        final addedAtStr = entry['addedAt'] as String?;
        if (stockId == null || farmerId == null) continue;
        final stock = await _supabaseService.getCoffeeStockById(stockId);
        final farmer = await _supabaseService.getProfile(farmerId);
        if (stock == null || farmer == null) continue;
        loaded[stockId] = CartItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          buyerId: widget.buyer.id!,
          stock: stock,
          farmer: farmer,
          quantityKg: quantity,
          addedAt: parseDateSafe(addedAtStr) ?? DateTime.now(),
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

  Future<void> _onCallPressed(String farmerId) async {
    try {
      final farmer = await _supabaseService.getProfile(farmerId);
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
    final refreshed = await _supabaseService.getProfile(widget.buyer.id!);
    if (refreshed == null || !mounted) return;
    setState(() {
      _currentBuyer = refreshed;
    });
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          currentUser: _currentBuyer,
          profileOwner: _currentBuyer,
        ),
      ),
    ).then((_) => _refreshCurrentBuyer());
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

  Widget _buildSoldBadge(ThemeData theme, {bool isSoldOut = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withAlpha((0.9 * 255).round()),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isSoldOut ? 'SOLD OUT' : 'SOLD',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onError,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSearchForm(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: CupertinoTextField(
        padding: const EdgeInsets.all(12),
        controller: _searchController,
        placeholder: "Search by coffee type",
        placeholderStyle: TextStyle(color: theme.hintColor.withValues(alpha: 0.5)),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Icon(CupertinoIcons.search, color: theme.colorScheme.primary),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
        ),
        style: TextStyle(color: theme.colorScheme.onSurface),
      ),
    );
  }

  Widget _buildHomeShortcuts(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.7),
            theme.colorScheme.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _shortcutItem(theme, "Cart", Icons.shopping_cart, () => _openCart(), badgeCount: _cartItemCount > 0 ? _cartItemCount : null),
          _shortcutItem(theme, "Messages", Icons.message, () => _openMessages(), badgeCount: _unreadMessageCount),
          _shortcutItem(theme, "Orders", Icons.receipt_long, () => _openPurchaseHistory()),
          _shortcutItem(theme, "Favorites", Icons.favorite, () => _openFavorites()),
          _shortcutItem(theme, "Alerts", Icons.notifications, () => _openNotifications(), badgeCount: _unreadNotificationCount),
        ],
      ),
    );
  }

  Widget _shortcutItem(ThemeData theme, String text, IconData icon, VoidCallback onTap, {int? badgeCount}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: theme.colorScheme.primary, size: 36),
              ),
              if (badgeCount != null && badgeCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Center(
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _openCart() async {
    final result = await Navigator.push<Map<String, CartItem>>(
      context,
      MaterialPageRoute(builder: (context) => CartScreen(buyer: widget.buyer, cartItems: _cart)),
    );
    if (result != null) {
      setState(() {
        _cart = result;
        _cartItemCount = _cart.length;
      });
      _saveCartToPrefs();
    }
  }

  void _openMessages() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ConversationsScreen(currentUser: widget.buyer))).then((_) => _getUnreadMessageCount());
  }

  void _openFavorites() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => FavoritesScreen(currentUser: widget.buyer)));
  }

  void _openPurchaseHistory() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PurchaseHistoryScreen(currentUser: _currentBuyer)));
  }

  void _openNotifications() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsScreen(currentUser: _currentBuyer)));
    _getUnreadNotificationCount();
  }

  Widget _buildSectionHeader(ThemeData theme, String title, {VoidCallback? onAction}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              child: const Text("See All"),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleLogoutRequest();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.9),
          elevation: 0,
          foregroundColor: theme.colorScheme.onPrimary,
          iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),
          title: const Text(
            'Home',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _openNotifications,
              icon: Stack(
                children: [
                  Icon(Icons.notifications_none, color: theme.colorScheme.onPrimary),
                  if (_unreadNotificationCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.colorScheme.primary, width: 1),
                        ),
                        constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: GestureDetector(
                onTap: _openProfile,
                child: CompositedTransformTarget(
                  link: _profileLink,
                  child: AppAvatar(
                    key: _profileKey,
                    filePath: _currentBuyer.profilePicturePath,
                    imageUrl: _currentBuyer.profilePicturePath,
                    size: 36,
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserSelectionScreen(
                  currentUser: _currentBuyer,
                  targetType: kaawa.UserType.farmer,
                ),
              ),
            );
          },
          backgroundColor: theme.colorScheme.primary,
          child: const Icon(Icons.chat_bubble_outline),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _coffeeStockStream = _supabaseService.getAllCoffeeStockStream();
            });
            await _refreshCurrentBuyer();
            await _loadCartFromPrefs();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: StreamBuilder<List<CoffeeStock>>(
              stream: _coffeeStockStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _allCoffeeStock.isEmpty) {
                  return _buildShimmerLoading(theme);
                }
                if (snapshot.hasData) {
                  _allCoffeeStock = snapshot.data!;
                  final query = _searchController.text.toLowerCase();
                  _filteredCoffeeStock = _allCoffeeStock.where((stock) {
                    return stock.coffeeType.toLowerCase().contains(query);
                  }).toList();
                }

                if (_allCoffeeStock.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
                  return _buildEmptyState(theme);
                }

                return ListView(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight + 10),
                  children: [
                    _buildSearchForm(theme),
                    _buildHomeShortcuts(theme),
                    _buildSectionHeader(theme, "Featured Listings"),
                    _buildHorizontalList(theme),
                    _buildSectionHeader(theme, "All Coffee Stock"),
                    _buildCoffeeGrid(theme),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.eco_outlined, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text("No coffee stock available", style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text("Check back later for fresh listings from farmers.", style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => setState(() => _coffeeStockStream = _supabaseService.getAllCoffeeStockStream()),
                child: const Text("Refresh"),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _refreshLocation,
                icon: const Icon(Icons.my_location),
                label: const Text("Refresh Location"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _refreshLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied.')));
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied.')));
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      await _supabaseService.updateProfile(_currentBuyer.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
      ));
      await _refreshCurrentBuyer();
      await _refreshCurrentBuyer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location updated successfully.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating location: $e')));
      }
    }
  }

  Widget _buildShimmerLoading(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceVariant,
      highlightColor: theme.colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight + 10),
        children: [
          Container(height: 50, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
          Container(height: 120, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
          const SizedBox(height: 20),
          Container(height: 30, width: 150, color: Colors.white),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (_, __) => Container(width: 200, margin: const EdgeInsets.only(right: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 20),
          Container(height: 30, width: 150, color: Colors.white),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.75),
            itemCount: 4,
            itemBuilder: (_, __) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalList(ThemeData theme) {
    final featured = _allCoffeeStock.take(5).toList();
    if (featured.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: featured.length,
        itemBuilder: (context, index) {
          final stock = featured[index];
          final images = _parseImages(stock.coffeePicturePath);
          final radius = BorderRadius.circular(12);

          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 15),
            child: Card(
              elevation: 4,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: radius),
              child: InkWell(
                onTap: () async {
                  final farmer = await _supabaseService.getProfile(stock.farmerId);
                  if (!mounted) return;
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(
                        stock: stock,
                        farmer: farmer,
                        currentUser: widget.buyer,
                        heroTag: 'stock_featured_${stock.id}',
                      ),
                    ),
                  );
                  if (result != null && result['action'] == 'add_to_cart' && farmer != null) {
                    _addToCart(stock, farmer, result['quantity'] as double);
                  }
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Hero(
                        tag: 'stock_featured_${stock.id}',
                        child: ListingCarousel(images: images, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              theme.colorScheme.primary.withValues(alpha: 0.2),
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "Featured",
                                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                                ),
                              ),
                              if (stock.quantity > 500)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade700,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "Bulk",
                                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stock.coffeeType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "UGX ${stock.pricePerKg}/kg",
                                style: const TextStyle(color: Colors.white70),
                              ),
                              if (stock.isSold || stock.quantityRemaining <= 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: _buildSoldBadge(theme, isSoldOut: stock.quantityRemaining <= 0),
                                ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _buildCoffeeGrid(ThemeData theme) {
    if (_filteredCoffeeStock.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text("No coffee stock found.")),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.7,
      ),
      itemCount: _filteredCoffeeStock.length,
      itemBuilder: (context, index) {
        final stock = _filteredCoffeeStock[index];
        final images = _parseImages(stock.coffeePicturePath);
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () async {
              final farmer = await _supabaseService.getProfile(stock.farmerId);
              if (!mounted) return;
              final result = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(
                    stock: stock,
                    farmer: farmer,
                    currentUser: widget.buyer,
                    heroTag: 'stock_grid_${stock.id}',
                  ),
                ),
              );
              if (result != null && result['action'] == 'add_to_cart' && farmer != null) {
                _addToCart(stock, farmer, result['quantity'] as double);
              }
            },
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Hero(
                          tag: 'stock_grid_${stock.id}',
                          child: ListingCarousel(images: images, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stock.coffeeType, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text("UGX ${stock.pricePerKg}/kg", style: theme.textTheme.bodySmall, maxLines: 1),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (!stock.isSold && stock.quantityRemaining > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
                                  child: Text("${stock.quantityRemaining} Kg Available", style: theme.textTheme.labelSmall?.copyWith(fontSize: 9)),
                                )
                              else
                                _buildSoldBadge(theme, isSoldOut: stock.quantityRemaining <= 0),
                              const SizedBox(width: 4),
                              if (stock.pricePerKg < 5000 && !stock.isSold && stock.quantityRemaining > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: Text("Best Price", style: theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: Colors.green.shade800)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!stock.isSold && stock.quantityRemaining > 0)
                  Positioned(
                    right: 4,
                    bottom: 40,
                    child: FloatingActionButton.small(
                      heroTag: 'quick_add_${stock.id}',
                      onPressed: () async {
                        final farmer = await _supabaseService.getProfile(stock.farmerId);
                        if (farmer != null) {
                          _addToCart(stock, farmer, 1.0);
                        }
                      },
                      child: const Icon(Icons.add),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
