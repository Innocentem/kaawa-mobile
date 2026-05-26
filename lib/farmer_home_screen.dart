import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kaawa/auth_service.dart';
import 'package:kaawa/chat_screen.dart';
import 'package:kaawa/conversations_screen.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/data/database_helper.dart';
import 'package:kaawa/welcome_screen.dart';
import 'package:kaawa/manage_stock_screen.dart';
import 'package:kaawa/profile_screen.dart';
import 'package:kaawa/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/widgets/compact_loader.dart';
import 'package:kaawa/interested_buyers_screen.dart';
import 'package:kaawa/data/coffee_stock_data.dart';
import 'package:kaawa/notifications_screen.dart';
import 'package:kaawa/purchase_requests_screen.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:kaawa/user_selection_screen.dart';
import 'dart:ui';

class FarmerHomeScreen extends StatefulWidget {
  final kaawa.User farmer;
  const FarmerHomeScreen({super.key, required this.farmer});

  @override
  State<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends State<FarmerHomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late Future<List<kaawa.User>> _buyersFuture;
  List<kaawa.User> _allBuyers = [];
  List<kaawa.User> _filteredBuyers = [];
  final _searchController = TextEditingController();
  bool _sortByDistance = false;
  bool _isGridView = true;
  Set<String> _favoriteUserIds = {};
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _unreadMessageCount = 0;
  int _unreadNotificationCount = 0;
  int _totalInterestedCount = 0;
  int _purchaseRequestCount = 0;
  StreamSubscription<int>? _messageSubscription;
  StreamSubscription<int>? _interestSubscription;
  StreamSubscription<int>? _purchaseSubscription;
  StreamSubscription<int>? _notificationSubscription;
  StreamSubscription<Map<String, List<kaawa.User>>>? _interestedBuyersSubscription;
  Map<String, List<kaawa.User>> _interestedByStock = {};
  List<CoffeeStock> _farmerStocks = [];
  final AuthService _auth_service = AuthService();
  final SupabaseService _supabaseService = SupabaseService.instance;

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
    await _auth_service.logout();
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

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open dialer')),
        );
      }
    }
  }

  Map<String, double> _buyerRatings = {};
  Map<String, int> _buyerReviewCounts = {};
  late kaawa.User _currentFarmer;

  final LayerLink _profileLink = LayerLink();
  final LayerLink _addListingLink = LayerLink();
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _addListingKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentFarmer = widget.farmer;
    _checkSuspensionAndLogout();
    _buyersFuture = _getBuyers();
    _searchController.addListener(_filterBuyers);
    _loadFavorites();
    _getUnreadMessageCount();
    _getUnreadNotificationCount();
    _getPurchaseRequestCount();
    _loadTotalInterestCount();
    _loadInterestedOverview();

    _messageSubscription = _supabaseService.getUnreadMessageCountStream(widget.farmer.id!).listen((count) {
      if (mounted) setState(() => _unreadMessageCount = count);
    });

    _interestSubscription = _supabaseService.getInterestedCountStreamForFarmer(widget.farmer.id!).listen((count) {
      if (mounted) setState(() => _totalInterestedCount = count);
    });

    _purchaseSubscription = _supabaseService.getPurchaseRequestCountStreamForFarmer(widget.farmer.id!).listen((count) {
      if (mounted) setState(() => _purchaseRequestCount = count);
    });

    _notificationSubscription = _supabaseService.getUnreadNotificationCountStream(widget.farmer.id!).listen((count) {
      if (mounted) setState(() => _unreadNotificationCount = count);
    });

    _interestedBuyersSubscription = _supabaseService.getInterestedBuyersByStockStream(widget.farmer.id!).listen((map) {
      if (mounted) setState(() => _interestedByStock = map);
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageSubscription?.cancel();
    _interestSubscription?.cancel();
    _purchaseSubscription?.cancel();
    _notificationSubscription?.cancel();
    _interestedBuyersSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSuspensionAndLogout();
    }
  }

  Future<void> _checkSuspensionAndLogout([kaawa.User? user]) async {
    final current = user ?? await _supabaseService.getProfile(widget.farmer.id!);
    if (current == null || !current.isSuspended) return;

    if (!mounted) return;
    await _auth_service.logout();

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

  Future<void> _loadFavorites() async {
    final favorites = await _supabaseService.getFavorites(widget.farmer.id!);
    setState(() {
      _favoriteUserIds = favorites.map((user) => user.id!).toSet();
    });
  }

  Future<void> _getUnreadMessageCount() async {
    final count = await _supabaseService.getUnreadMessageCount(widget.farmer.id!);
    setState(() => _unreadMessageCount = count);
  }

  Future<void> _getUnreadNotificationCount() async {
    final count = await _supabaseService.getUnreadNotificationCount(widget.farmer.id!);
    setState(() => _unreadNotificationCount = count);
  }

  Future<void> _getPurchaseRequestCount() async {
    final count = await _supabaseService.getPurchaseRequestCountForFarmer(widget.farmer.id!);
    setState(() => _purchaseRequestCount = count);
  }

  Future<List<kaawa.User>> _getBuyers() async {
    final buyers = await _supabaseService.getAllProfiles();
    final onlyBuyers = buyers.where((u) => u.userType == kaawa.UserType.buyer).toList();
    _allBuyers = onlyBuyers;
    _filteredBuyers = onlyBuyers;

    // preload ratings
    for (var b in onlyBuyers) {
      final stats = await _supabaseService.getRatingSummaryForUser(b.id!);
      _buyerRatings[b.id!] = (stats['averageRating'] ?? 0.0) as double;
      _buyerReviewCounts[b.id!] = (stats['reviewCount'] ?? 0) as int;
    }

    return onlyBuyers;
  }

  void _filterBuyers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBuyers = _allBuyers.where((buyer) {
        return buyer.fullName.toLowerCase().contains(query) ||
            buyer.district.toLowerCase().contains(query);
      }).toList();

      if (_sortByDistance && _currentFarmer.latitude != null && _currentFarmer.longitude != null) {
        _filteredBuyers.sort((a, b) {
          if (a.latitude == null || a.longitude == null) return 1;
          if (b.latitude == null || b.longitude == null) return -1;

          final distanceA = Geolocator.distanceBetween(
            _currentFarmer.latitude!,
            _currentFarmer.longitude!,
            a.latitude!,
            a.longitude!,
          );
          final distanceB = Geolocator.distanceBetween(
            _currentFarmer.latitude!,
            _currentFarmer.longitude!,
            b.latitude!,
            b.longitude!,
          );
          return distanceA.compareTo(distanceB);
        });
      }
    });
  }

  Future<void> _toggleFavorite(String buyerId) async {
    if (_favoriteUserIds.contains(buyerId)) {
      await _supabaseService.removeFavorite(widget.farmer.id!, buyerId);
    } else {
      await _supabaseService.addFavorite(widget.farmer.id!, buyerId);
    }
    _loadFavorites();
  }

  Widget _buildSearchForm(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: CupertinoTextField(
        padding: const EdgeInsets.all(12),
        controller: _searchController,
        placeholder: "Search by name or district",
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
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _shortcutItem(theme, "Manage Stock", Icons.inventory, _openManageStock),
          _shortcutItem(theme, "Messages", Icons.message, _openMessages, badgeCount: _unreadMessageCount),
          _shortcutItem(theme, "Requests", Icons.shopping_bag, _openRequests, badgeCount: _purchaseRequestCount),
          _shortcutItem(theme, "Alerts", Icons.notifications, _openNotifications, badgeCount: _unreadNotificationCount),
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

  void _openManageStock() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ManageStockScreen(farmer: _currentFarmer)),
    );
    _loadTotalInterestCount();
  }

  void _openMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ConversationsScreen(currentUser: widget.farmer)),
    ).then((_) {
      _getUnreadMessageCount();
      _loadInterestedOverview();
    });
  }

  void _openRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PurchaseRequestsScreen(currentUser: _currentFarmer)),
    );
    _getPurchaseRequestCount();
  }

  void _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NotificationsScreen(currentUser: _currentFarmer)),
    );
    await _getUnreadNotificationCount();
  }

  Future<void> _loadTotalInterestCount() async {
    final count = await _supabaseService.getUnreadInterestedCountForFarmer(widget.farmer.id!);
    setState(() {
      _totalInterestedCount = count;
    });
  }

  Future<void> _loadInterestedOverview() async {
    try {
      final stocks = await _supabaseService.getCoffeeStockByFarmer(widget.farmer.id!);
      final Map<String, List<kaawa.User>> map = {};
      // parallel fetch interested buyers per stock
      await Future.wait(stocks.map((s) async {
        if (s.id != null) {
          final buyers = await _supabaseService.getInterestedBuyersForStock(s.id!);
          if (buyers.isNotEmpty) {
            map[s.id!] = buyers;
          }
        }
      }));

      final total = await _supabaseService.getUnreadInterestedCountForFarmer(widget.farmer.id!);

      setState(() {
        _farmerStocks = stocks;
        _interestedByStock = map;
        _totalInterestedCount = total;
      });
    } catch (_) {
      // ignore errors silently for periodic refresh
    }
  }

  Future<void> _refreshBuyers() async {
    setState(() {
      _buyersFuture = _getBuyers();
    });
    await _buyersFuture;
    await _refreshCurrentFarmer();
    await _loadInterestedOverview();
  }

  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
    });
  }

  Future<void> _refreshCurrentFarmer() async {
    final refreshed = await _supabaseService.getProfile(widget.farmer.id!);
    if (refreshed == null) return;
    setState(() {
      _currentFarmer = refreshed;
    });
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
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AppBar(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.7),
                elevation: 0,
                foregroundColor: theme.colorScheme.onPrimary,
                iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
                actionsIconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Center(
                    child: Semantics(
                      label: 'Open profile',
                      button: true,
                      child: Tooltip(
                        message: 'Open profile',
                        child: CompositedTransformTarget(
                          link: _profileLink,
                          child: InkWell(
                            key: _profileKey,
                            borderRadius: BorderRadius.circular(28),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileScreen(
                                    currentUser: _currentFarmer,
                                    profileOwner: _currentFarmer,
                                  ),
                                ),
                              ).then((_) => _refreshCurrentFarmer());
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AppAvatar(
                                  filePath: _currentFarmer.profilePicturePath,
                                  imageUrl: _currentFarmer.profilePicturePath,
                                  size: 36,
                                ),
                                if (_unreadNotificationCount > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.error,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: theme.colorScheme.primary, width: 1.5),
                                      ),
                                      constraints: const BoxConstraints(
                                          minWidth: 14, minHeight: 14),
                                      child: Center(
                                        child: Text(
                                          _unreadNotificationCount > 99
                                              ? '99+'
                                              : '$_unreadNotificationCount',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold),
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
                  ),
                ),
                title: Image.asset(
                  'assets/icons/pngwing.png',
                  height: 32,
                  fit: BoxFit.contain,
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                    onPressed: _toggleViewMode,
                    tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'farmer_chat_fab',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserSelectionScreen(
                      currentUser: _currentFarmer,
                      targetType: kaawa.UserType.buyer,
                    ),
                  ),
                );
              },
              backgroundColor: theme.colorScheme.secondary,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            const SizedBox(height: 16),
            CompositedTransformTarget(
              link: _addListingLink,
              child: FloatingActionButton.extended(
                key: _addListingKey,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageStockScreen(farmer: widget.farmer),
                    ),
                  );
                  _loadInterestedOverview();
                },
                label: const Text('Manage Stock'),
                icon: const Icon(Icons.inventory),
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refreshBuyers,
          edgeOffset: MediaQuery.of(context).padding.top + kToolbarHeight,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchForm(theme),
                _buildHomeShortcuts(theme),
                _buildInterestedOverview(theme),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Coffee Buyers",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _sortByDistance ? Icons.location_on : Icons.location_off,
                        color: _sortByDistance ? theme.colorScheme.primary : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _sortByDistance = !_sortByDistance;
                          _filterBuyers();
                        });
                      },
                      tooltip: _sortByDistance ? 'Sorting by distance' : 'Distance sorting off',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<kaawa.User>>(
                  future: _buyersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && _allBuyers.isEmpty) {
                      return const Center(child: CompactLoader());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (_filteredBuyers.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text("No buyers found."),
                        ),
                      );
                    }

                    return _isGridView ? _buildBuyerGrid(theme) : _buildBuyerList(theme);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInterestedOverview(ThemeData theme) {
    if (_totalInterestedCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                "Interest Overview",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const Spacer(),
              Text(
                "$_totalInterestedCount interested",
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _farmerStocks.length,
              itemBuilder: (context, index) {
                final stock = _farmerStocks[index];
                final buyers = _interestedByStock[stock.id!] ?? [];
                if (buyers.isEmpty) return const SizedBox.shrink();

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InterestedBuyersScreen(
                          stock: stock,
                          currentUser: _currentFarmer,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(stock.coffeeType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: theme.colorScheme.secondary, shape: BoxShape.circle),
                          child: Text(
                            "${buyers.length}",
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerGrid(ThemeData theme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: _filteredBuyers.length,
      itemBuilder: (context, index) {
        final buyer = _filteredBuyers[index];
        final avgRating = _buyerRatings[buyer.id] ?? 0.0;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _openBuyerProfile(buyer),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      AppAvatar(
                        filePath: buyer.profilePicturePath,
                        imageUrl: buyer.profilePicturePath,
                        size: 60,
                      ),
                      GestureDetector(
                        onTap: () => _toggleFavorite(buyer.id!),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                          child: Icon(
                            _favoriteUserIds.contains(buyer.id) ? Icons.favorite : Icons.favorite_border,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    buyer.fullName,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    buyer.district,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBuyerList(ThemeData theme) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredBuyers.length,
      itemBuilder: (context, index) {
        final buyer = _filteredBuyers[index];
        final avgRating = _buyerRatings[buyer.id] ?? 0.0;
        final reviewCount = _buyerReviewCounts[buyer.id] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: AppAvatar(
              filePath: buyer.profilePicturePath,
              imageUrl: buyer.profilePicturePath,
              size: 50,
            ),
            title: Text(buyer.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(buyer.district),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text("$avgRating ($reviewCount reviews)", style: theme.textTheme.labelSmall),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () => _makePhoneCall(buyer.phoneNumber),
                ),
                IconButton(
                  icon: Icon(
                    _favoriteUserIds.contains(buyer.id) ? Icons.favorite : Icons.favorite_border,
                    color: Colors.red,
                  ),
                  onPressed: () => _toggleFavorite(buyer.id!),
                ),
              ],
            ),
            onTap: () => _openBuyerProfile(buyer),
          ),
        );
      },
    );
  }

  void _openBuyerProfile(kaawa.User buyer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          currentUser: _currentFarmer,
          profileOwner: buyer,
        ),
      ),
    );
  }
}
