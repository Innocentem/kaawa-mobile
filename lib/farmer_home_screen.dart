import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kaawa_mobile/auth_service.dart';
import 'package:kaawa_mobile/chat_screen.dart';
import 'package:kaawa_mobile/conversations_screen.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/welcome_screen.dart';
import 'package:kaawa_mobile/manage_stock_screen.dart';
import 'package:kaawa_mobile/profile_screen.dart';
import 'package:kaawa_mobile/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kaawa_mobile/widgets/app_avatar.dart';
import 'package:kaawa_mobile/widgets/compact_loader.dart';
import 'package:kaawa_mobile/interested_buyers_screen.dart';
import 'package:kaawa_mobile/data/coffee_stock_data.dart';

class FarmerHomeScreen extends StatefulWidget {
  final User farmer;
  const FarmerHomeScreen({super.key, required this.farmer});

  @override
  State<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends State<FarmerHomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late Future<List<User>> _buyersFuture;
  List<User> _allBuyers = [];
  List<User> _filteredBuyers = [];
  final _searchController = TextEditingController();
  bool _sortByDistance = false;
  Set<int> _favoriteUserIds = {};
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _unreadMessageCount = 0;
  int _totalInterestedCount = 0;
  Timer? _refreshTimer;
  Map<int, List<User>> _interestedByStock = {};
  List<CoffeeStock> _farmerStocks = [];
  final AuthService _auth_service = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSuspensionAndLogout();
    _buyersFuture = _getBuyers();
    _searchController.addListener(_filterBuyers);
    _loadFavorites();
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
    _loadTotalInterestCount();
    _loadInterestedOverview();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadInterestedOverview());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
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
    final current = await DatabaseHelper.instance.getUserById(widget.farmer.id!);
    if (current == null || !current.isSuspended) return;
    await _auth_service.logout();
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

  Future<void> _loadFavorites() async {
    final favorites = await DatabaseHelper.instance.getFavorites(widget.farmer.id!);
    setState(() {
      _favoriteUserIds = favorites.map((user) => user.id!).toSet();
    });
  }

  Future<void> _getUnreadMessageCount() async {
    final count = await DatabaseHelper.instance.getUnreadMessageCount(widget.farmer.id!);
    setState(() {
      _unreadMessageCount = count;
    });
  }

  Future<List<User>> _getBuyers() async {
    final allUsers = await DatabaseHelper.instance.getAllUsers();
    return allUsers.where((user) => user.userType == UserType.buyer).toList();
  }

  void _filterBuyers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBuyers = _allBuyers.where((buyer) {
        final nameLower = buyer.fullName.toLowerCase();
        final districtLower = buyer.district.toLowerCase();
        return nameLower.contains(query) ||
            districtLower.contains(query);
      }).toList();
    });
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

  Future<void> _toggleFavorite(int buyerId) async {
    if (_favoriteUserIds.contains(buyerId)) {
      await DatabaseHelper.instance.removeFavorite(widget.farmer.id!, buyerId);
    } else {
      await DatabaseHelper.instance.addFavorite(widget.farmer.id!, buyerId);
    }
    _loadFavorites();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch dialer for $phoneNumber')), 
      );
    }
  }

  Future<void> _logout() async {
    await _auth_service.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _loadTotalInterestCount() async {
    final count = await DatabaseHelper.instance.getTotalInterestCountForFarmer(widget.farmer.id!);
    setState(() {
      _totalInterestedCount = count;
    });
  }

  Future<void> _loadInterestedOverview() async {
    try {
      final stocks = await DatabaseHelper.instance.getCoffeeStock(widget.farmer.id!);
      final Map<int, List<User>> map = {};
      // parallel fetch interested buyers per stock
      await Future.wait(stocks.map((s) async {
        if (s.id != null) {
          final buyers = await DatabaseHelper.instance.getInterestedBuyersForStock(s.id!);
          if (buyers.isNotEmpty) {
            map[s.id!] = buyers;
          }
        }
      }));

      final total = await DatabaseHelper.instance.getTotalInterestCountForFarmer(widget.farmer.id!);

      setState(() {
        _farmerStocks = stocks;
        _interestedByStock = map;
        _totalInterestedCount = total;
      });
    } catch (_) {
      // ignore errors silently for periodic refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // compute scale-aware sizes so cards don't overflow with large text settings
    final textScale = MediaQuery.of(context).textScaleFactor;
    // Allow a larger maximum card height to accommodate extreme text scaling
    final cardHeight = (120 * textScale).clamp(100.0, 320.0);
    final avatarSize = (44 * textScale).clamp(32.0, 80.0);

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
              borderRadius: BorderRadius.circular(28),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(currentUser: widget.farmer, profileOwner: widget.farmer),
                  ),
                );
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(filePath: widget.farmer.profilePicturePath, imageUrl: widget.farmer.profilePicturePath, size: 44),
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
                      builder: (context) => ConversationsScreen(currentUser: widget.farmer),
                    ),
                  ).then((_) {
                    // refresh unread messages count when returning
                    _getUnreadMessageCount();
                    // also refresh conversations/overview
                    _loadInterestedOverview();
                  });
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
                  builder: (context) => ProfileScreen(currentUser: widget.farmer, profileOwner: widget.farmer),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
          // Manage stock + interested buyers shortcut (shows badge with total interested buyers)
          IconButton(
            icon: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.group),
                if (_totalInterestedCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle),
                      child: Text('$_totalInterestedCount', style: TextStyle(color: theme.colorScheme.onError, fontSize: 10)),
                    ),
                  ),
              ],
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManageStockScreen(farmer: widget.farmer),
                ),
              );
              // refresh count after returning
              _loadTotalInterestCount();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Interested buyers overview - shown only when there are interested buyers
            if (_interestedByStock.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Interested Buyers', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                                                child: Hero(
                                                  tag: buyers[0].id != null ? 'avatar-${buyers[0].id}' : UniqueKey(),
                                                  child: Material(
                                                    type: MaterialType.transparency,
                                                    child: AppAvatar(
                                                      filePath: buyers[0].profilePicturePath,
                                                      imageUrl: buyers[0].profilePicturePath,
                                                      size: avatarSize,
                                                    ),
                                                  ),
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
            Text('Available Buyers', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Tap on a buyer to view their profile. Use the star to mark as favorite, or the message icon to start a conversation.',
              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: theme.textTheme.bodySmall == null ? null : theme.textTheme.bodySmall!.color!.withAlpha((0.75 * 255).round())),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by name or district',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.sort),
              label: Text(_sortByDistance ? 'Sort by Name' : 'Sort by Distance'),
              onPressed: _toggleSortByDistance,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<User>>(
                future: _buyersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: SizedBox(height: 200, child: Center(child: CompactLoader(size: 28, strokeWidth: 3.0, semanticsLabel: 'Loading buyers'))));
                  } else if (snapshot.hasError) {
                    return const Center(child: Text('Error loading buyers.'));
                  } else {
                    _allBuyers = snapshot.data ?? [];
                    _filteredBuyers = List.from(_allBuyers);

                    final Widget content = _filteredBuyers.isEmpty && _searchController.text.isNotEmpty
                        ? const Center(child: Text('No buyers found.'))
                        : GridView.builder(
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
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        AspectRatio(
                                          aspectRatio: 1,
                                          child: AppAvatar(
                                            filePath: buyer.profilePicturePath,
                                            imageUrl: buyer.profilePicturePath,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(buyer.fullName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text('District: ${buyer.district}'),
                                              if (distance != null) Text('${distance.toStringAsFixed(1)} km away'),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            IconButton(
                                              icon: Icon(isFavorite ? Icons.star : Icons.star_border, color: isFavorite ? theme.colorScheme.secondary : theme.textTheme.bodySmall?.color),
                                              onPressed: () => _toggleFavorite(buyer.id!),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.message),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChatScreen(currentUser: widget.farmer, otherUser: buyer),
                                                  ),
                                                ).then((_) => _getUnreadMessageCount());
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.phone),
                                              onPressed: () => _makePhoneCall(buyer.phoneNumber),
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

                    return FadeTransition(opacity: _animation, child: content);
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

