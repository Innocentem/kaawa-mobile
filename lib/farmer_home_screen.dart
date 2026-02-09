
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kaawa_mobile/auth_service.dart';
import 'package:kaawa_mobile/chat_screen.dart';
import 'package:kaawa_mobile/conversations_screen.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/favorites_screen.dart';
import 'package:kaawa_mobile/welcome_screen.dart';
import 'package:kaawa_mobile/manage_stock_screen.dart';
import 'package:kaawa_mobile/profile_screen.dart';
import 'package:kaawa_mobile/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class FarmerHomeScreen extends StatefulWidget {
  final User farmer;
  const FarmerHomeScreen({super.key, required this.farmer});

  @override
  State<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends State<FarmerHomeScreen> with TickerProviderStateMixin {
  late Future<List<User>> _buyersFuture;
  List<User> _allBuyers = [];
  List<User> _filteredBuyers = [];
  final _searchController = TextEditingController();
  bool _sortByDistance = false;
  Set<int> _favoriteUserIds = {};
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _unreadMessageCount = 0;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    await _authService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.farmer.fullName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
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
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_unreadMessageCount',
                      style: const TextStyle(
                        color: Colors.white,
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
            const Text('Available Buyers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Tap on a buyer to view their profile. Use the star to mark as favorite, or the message icon to start a conversation.',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
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
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return const Center(child: Text('Error loading buyers.'));
                  } else {
                    _allBuyers = snapshot.data ?? [];
                    _filteredBuyers = List.from(_allBuyers);
                    return FadeTransition(
                      opacity: _animation,
                      child: _filteredBuyers.isEmpty && _searchController.text.isNotEmpty
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
                                final distance = widget.farmer.latitude != null &&
                                        widget.farmer.longitude != null &&
                                        buyer.latitude != null &&
                                        buyer.longitude != null
                                    ? Geolocator.distanceBetween(
                                        widget.farmer.latitude!,
                                        widget.farmer.longitude!,
                                        buyer.latitude!,
                                        buyer.longitude!,
                                      ) / 1000
                                    : null;
                                return Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProfileScreen(currentUser: widget.farmer, profileOwner: buyer),
                                        ),
                                      );
                                    },
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          AspectRatio(
                                            aspectRatio: 1,
                                            child: CircleAvatar(
                                              radius: 30,
                                              backgroundImage: buyer.profilePicturePath != null
                                                  ? FileImage(File(buyer.profilePicturePath!))
                                                  : null,
                                              child: buyer.profilePicturePath == null
                                                  ? const Icon(Icons.person, size: 30)
                                                  : null,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(buyer.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 4),
                                                Text('District: ${buyer.district}'),
                                                if (distance != null)
                                                  Text('${distance.toStringAsFixed(1)} km away'),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                                            children: [
                                              IconButton(
                                                icon: Icon(isFavorite ? Icons.star : Icons.star_border, color: isFavorite ? Colors.amber : Colors.grey),
                                                onPressed: () => _toggleFavorite(buyer.id!),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.message),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => ChatScreen(
                                                        currentUser: widget.farmer,
                                                        otherUser: buyer,
                                                      ),
                                                    ),
                                                  );
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
