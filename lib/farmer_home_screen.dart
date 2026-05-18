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
import 'package:kaawa/review_notifications_screen.dart';
import 'package:kaawa/purchase_requests_screen.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Set<String> _favoriteUserIds = {};
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _unreadMessageCount = 0;
  int _unreadReviewCount = 0;
  int _totalInterestedCount = 0;
  int _purchaseRequestCount = 0;
  StreamSubscription<int>? _messageSubscription;
  StreamSubscription<int>? _interestSubscription;
  StreamSubscription<int>? _purchaseSubscription;
  StreamSubscription<int>? _reviewSubscription;
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
    _getUnreadReviewCount();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();

    _messageSubscription = _supabaseService.getUnreadMessageCountStream(widget.farmer.id!).listen((count) {
      if (mounted) setState(() => _unreadMessageCount = count);
    });

    _interestSubscription = _supabaseService.getInterestedCountStreamForFarmer(widget.farmer.id!).listen((count) {
      if (mounted) {
        setState(() => _totalInterestedCount = count);
      }
    });

    _purchaseSubscription = _supabaseService.getPurchaseRequestCountStreamForFarmer(widget.farmer.id!).listen((count) {
      if (mounted) setState(() => _purchaseRequestCount = count);
    });

    _reviewSubscription = _supabaseService.getUnreadReviewNotificationCountStream(widget.farmer.id!).listen((count) {
      if (mounted) setState(() => _unreadReviewCount = count);
    });

    _interestedBuyersSubscription = _supabaseService.getInterestedBuyersByStockStream(widget.farmer.id!).listen((map) {
      if (mounted) {
        setState(() {
          _interestedByStock = map;
        });
      }
    });

    _loadTotalInterestCount();
    _loadInterestedOverview();
    _scheduleOnboardingGuides();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageSubscription?.cancel();
    _interestSubscription?.cancel();
    _purchaseSubscription?.cancel();
    _reviewSubscription?.cancel();
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

  Future<void> _checkSuspensionAndLogout() async {
    final current = await _supabaseService.getProfile(widget.farmer.id!);
    if (current == null || !current.isSuspended) return;
    await _auth_service.logout();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
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

  Future<void> _loadFavorites() async {
    final favorites = await _supabaseService.getFavorites(widget.farmer.id!);
    setState(() {
      _favoriteUserIds = favorites.map((user) => user.id!).toSet();
    });
  }

  Future<void> _getUnreadMessageCount() async {
    final count = await _supabaseService.getUnreadMessageCount(widget.farmer.id!);
    setState(() {
      _unreadMessageCount = count;
    });
  }

  Future<void> _getUnreadReviewCount() async {
    final count = await _supabaseService.getUnreadReviewNotificationCount(widget.farmer.id!);
    if (!mounted) return;
    setState(() => _unreadReviewCount = count);
  }

  Future<void> _getPurchaseRequestCount() async {
    final requests = await _supabaseService.getPurchaseRequestsForFarmer(widget.farmer.id!);
    if (!mounted) return;
    setState(() {
      _purchaseRequestCount = requests.length;
    });
  }

  Future<List<kaawa.User>> _getBuyers() async {
    final allUsers = await _supabaseService.getAllProfiles();
    final buyers = allUsers.where((user) => user.userType == kaawa.UserType.buyer).toList();
    await _loadBuyerRatings(buyers);
    return buyers;
  }

  Future<void> _loadBuyerRatings(List<kaawa.User> buyers) async {
    final ratings = <String, double>{};
    final counts = <String, int>{};
    for (final buyer in buyers) {
      if (buyer.id == null) continue;
      final summary = await _supabaseService.getRatingSummaryForUser(buyer.id!);
      ratings[buyer.id!] = (summary['avg'] as num?)?.toDouble() ?? 0.0;
      counts[buyer.id!] = (summary['count'] as num?)?.toInt() ?? 0;
    }
    if (!mounted) return;
    setState(() {
      _buyerRatings = ratings;
      _buyerReviewCounts = counts;
    });
  }

  void _filterBuyers() {
    final query = _searchController.text.toLowerCase();
    final filtered = _allBuyers.where((buyer) {
      final nameLower = buyer.fullName.toLowerCase();
      final districtLower = buyer.district.toLowerCase();
      return nameLower.contains(query) || districtLower.contains(query);
    }).toList();

    if (filtered.length != _filteredBuyers.length || !filtered.every((b) => _filteredBuyers.contains(b))) {
      setState(() {
        _filteredBuyers = filtered;
      });
    }
  }

  Future<void> _ensureFarmerStocksLoaded() async {
    if (_farmerStocks.isNotEmpty) return;
    final stocks = await _supabaseService.getCoffeeStockByFarmer(widget.farmer.id!);
    if (!mounted) return;
    setState(() {
      _farmerStocks = stocks;
    });
  }

  Future<void> _shareListingToBuyer(kaawa.User buyer) async {
    await _ensureFarmerStocksLoaded();
    if (_farmerStocks.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a listing before sharing it.')));
      return;
    }

    final selected = await showModalBottomSheet<CoffeeStock>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: _farmerStocks.map((stock) {
              final label = '${stock.coffeeType} • ${stock.quantity} kg • UGX ${stock.pricePerKg}/kg';
              return ListTile(
                title: Text(stock.coffeeType),
                subtitle: Text(label),
                onTap: () => Navigator.pop(sheetContext, stock),
              );
            }).toList(),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    final message = 'Hi ${buyer.fullName}, I have ${selected.coffeeType} available. Interested?';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          currentUser: widget.farmer,
          otherUser: buyer,
          coffeeStock: selected,
          initialMessage: message,
        ),
      ),
    );
  }

  Widget _buildRatingRow(double rating, int count) {
    final whole = rating.round().clamp(0, 5);
    return Row(
      children: [
        ...List.generate(5, (i) {
          return Icon(
            i < whole ? Icons.star : Icons.star_border,
            size: 14,
            color: Colors.amber.shade700,
          );
        }),
        const SizedBox(width: 4),
        Text('($count)', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  void _toggleSortByDistance() {
    setState(() {
      _sortByDistance = !_sortByDistance;
      if (_sortByDistance) {
        _filteredBuyers.sort((a, b) {
          final distanceA = Geolocator.distanceBetween(
            widget.farmer.latitude!,
            widget.farmer.longitude!,
            a.latitude!,
            a.longitude!,
          );
          final distanceB = Geolocator.distanceBetween(
            widget.farmer.latitude!,
            widget.farmer.longitude!,
            b.latitude!,
            b.longitude!,
          );
          return distanceA.compareTo(distanceB);
        });
      } else {
        _filteredBuyers = List.from(_allBuyers);
        _filterBuyers();
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
        placeholderStyle: TextStyle(color: theme.hintColor.withOpacity(0.5)),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Icon(CupertinoIcons.search, color: theme.colorScheme.primary),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
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
            theme.colorScheme.primary.withOpacity(0.7),
            theme.colorScheme.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _shortcutItem(theme, "Stock", Icons.inventory, () => _openManageStock(), badgeCount: _totalInterestedCount),
          _shortcutItem(theme, "Messages", Icons.message, () => _openMessages(), badgeCount: _unreadMessageCount),
          _shortcutItem(theme, "Requests", Icons.shopping_bag, () => _openRequests(), badgeCount: _purchaseRequestCount),
          _shortcutItem(theme, "Reviews", Icons.star, () => _openReviews(), badgeCount: _unreadReviewCount),
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
      MaterialPageRoute(builder: (context) => PurchaseRequestsScreen(farmer: _currentFarmer)),
    );
    _getPurchaseRequestCount();
  }

  void _openReviews() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReviewNotificationsScreen(currentUser: _currentFarmer)),
    );
    await _getUnreadReviewCount();
  }

  Future<void> _loadTotalInterestCount() async {
    final count = await _supabaseService.getTotalInterestCountForFarmer(widget.farmer.id!);
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

      final total = await _supabaseService.getTotalInterestCountForFarmer(widget.farmer.id!);

      setState(() {
        _farmerStocks = stocks;
        _interestedByStock = map;
        _totalInterestedCount = total;
      });
    } catch (_) {
      // ignore errors silently for periodic refresh
    }
  }

  Future<void> _refreshCurrentFarmer() async {
    final refreshed = await _supabaseService.getProfile(widget.farmer.id!);
    if (refreshed == null || !mounted) return;
    setState(() {
      _currentFarmer = refreshed;
    });
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(currentUser: _currentFarmer, profileOwner: _currentFarmer),
      ),
    );
    await _refreshCurrentFarmer();
  }

  Future<void> _scheduleOnboardingGuides() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'guide_farmer_home_v1_${widget.farmer.id}';
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
        link: _addListingLink,
        targetKey: _addListingKey,
        title: 'Add a listing',
        message: 'Use this button to add your coffee stock listings.',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // compute scale-aware sizes so cards don't overflow with large text settings
    final textScale = MediaQuery.of(context).textScaleFactor;
    // Allow a larger maximum card height to accommodate extreme text scaling
    final cardHeight = (120 * textScale).clamp(100.0, 320.0);
    final avatarSize = (44 * textScale).clamp(32.0, 80.0);

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
                  borderRadius: BorderRadius.circular(28),
                  onTap: _openProfile,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AppAvatar(
                        filePath: _currentFarmer.profilePicturePath,
                        imageUrl: _currentFarmer.profilePicturePath,
                        size: 44,
                      ),
                      if (_unreadMessageCount > 0)
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.onError, width: 1.5)),
                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                            child: Center(
                              child: Text(
                                _unreadMessageCount > 99 ? '99+' : '$_unreadMessageCount',
                                style: TextStyle(color: theme.colorScheme.onError, fontSize: 11, fontWeight: FontWeight.bold),
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
        floatingActionButton: CompositedTransformTarget(
          link: _addListingLink,
          child: FloatingActionButton.extended(
            key: _addListingKey,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManageStockScreen(farmer: widget.farmer),
                ),
              );
            },
            label: const Text('Manage Stock'),
            icon: const Icon(Icons.inventory),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchForm(theme),
              _buildHomeShortcuts(theme),
              const SizedBox(height: 16),
              // Interested buyers overview - shown only when there are interested buyers
              if (_interestedByStock.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Interested Buyers', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Tap a card to view interested buyers per stock.',
                          child: Icon(Icons.info_outline, size: 18, color: IconTheme.of(context).color ?? theme.colorScheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: cardHeight,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _farmerStocks.length,
                        itemBuilder: (context, idx) {
                          final stock = _farmerStocks[idx];
                          if (stock.id == null) return const SizedBox.shrink();
                          final buyers = _interestedByStock[stock.id!] ?? [];
                          if (buyers.isEmpty) return const SizedBox.shrink();

                          return SizedBox(
                            width: 220,
                            height: cardHeight,
                            child: Card(
                              margin: const EdgeInsets.only(right: 12),
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => InterestedBuyersScreen(farmer: widget.farmer, stock: stock)),
                                  );
                                  _loadInterestedOverview();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                stock.coffeeType,
                                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (buyers.isNotEmpty)
                                              GestureDetector(
                                                onTap: () async {
                                                  final buyer = buyers[0];
                                                  await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(builder: (context) => ProfileScreen(currentUser: widget.farmer, profileOwner: buyer)),
                                                  );
                                                  _loadInterestedOverview();
                                                  _loadTotalInterestCount();
                                                  _getUnreadMessageCount();
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.only(left: 8.0),
                                                  child: AppAvatar(
                                                    filePath: buyers[0].profilePicturePath,
                                                    imageUrl: buyers[0].profilePicturePath,
                                                    size: avatarSize,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text('${buyers.length} interested', style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 6),
                                        Flexible(
                                          fit: FlexFit.loose,
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: List.generate(
                                              buyers.length > 3 ? 3 : buyers.length,
                                              (i) => AppAvatar(
                                                filePath: buyers[i].profilePicturePath,
                                                imageUrl: buyers[i].profilePicturePath,
                                                size: avatarSize,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (context) => InterestedBuyersScreen(farmer: widget.farmer, stock: stock)),
                                              );
                                              await _loadInterestedOverview();
                                              await _loadTotalInterestCount();
                                            },
                                            child: const Text('View all'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // Available buyers section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('Available Buyers', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Tap a buyer to view profile. Use star to favorite or message to chat.',
                        child: Icon(Icons.info_outline, size: 18, color: IconTheme.of(context).color ?? theme.colorScheme.primary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(_sortByDistance ? Icons.sort_by_alpha : Icons.near_me),
                    onPressed: _toggleSortByDistance,
                    tooltip: _sortByDistance ? 'Sort by Name' : 'Sort by Distance',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<kaawa.User>>(
                future: _buyersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: CompactLoader()));
                  } else if (snapshot.hasError) {
                    return const Center(child: Text('Error loading buyers.'));
                  } else {
                    _allBuyers = snapshot.data ?? [];
                    // Apply filtering logic locally to avoid build-time setState
                    final query = _searchController.text.toLowerCase();
                    _filteredBuyers = _allBuyers.where((buyer) {
                      final nameLower = buyer.fullName.toLowerCase();
                      final districtLower = buyer.district.toLowerCase();
                      return nameLower.contains(query) || districtLower.contains(query);
                    }).toList();

                    if (_filteredBuyers.isEmpty) {
                      return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No buyers found.')));
                    }
                    
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _filteredBuyers.length,
                      itemBuilder: (context, index) {
                        final buyer = _filteredBuyers[index];
                        final isFavorite = _favoriteUserIds.contains(buyer.id);
                        final distance = (widget.farmer.latitude != null &&
                                widget.farmer.longitude != null &&
                                buyer.latitude != null &&
                                buyer.longitude != null)
                            ? Geolocator.distanceBetween(widget.farmer.latitude!, widget.farmer.longitude!, buyer.latitude!, buyer.longitude!) / 1000
                            : null;

                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ProfileScreen(currentUser: widget.farmer, profileOwner: buyer)),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    child: AppAvatar(
                                      filePath: buyer.profilePicturePath,
                                      imageUrl: buyer.profilePicturePath,
                                      fit: BoxFit.cover,
                                      size: double.infinity,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(buyer.fullName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text('${buyer.district}', style: theme.textTheme.bodySmall),
                                      if (distance != null) Text('${distance.toStringAsFixed(1)} km away', style: theme.textTheme.labelSmall),
                                      const SizedBox(height: 4),
                                      _buildRatingRow(
                                        _buyerRatings[buyer.id] ?? 0.0,
                                        _buyerReviewCounts[buyer.id] ?? 0,
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      icon: Icon(isFavorite ? Icons.star : Icons.star_border, color: isFavorite ? Colors.amber : null, size: 20),
                                      onPressed: () => _toggleFavorite(buyer.id!),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.message, size: 20),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatScreen(currentUser: widget.farmer, otherUser: buyer),
                                          ),
                                        ).then((_) => _getUnreadMessageCount());
                                      },
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.phone, size: 20),
                                      onPressed: () => _makePhoneCall(buyer.phoneNumber),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
















