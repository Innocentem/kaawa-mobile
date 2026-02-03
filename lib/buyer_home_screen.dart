
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kaawa_mobile/chat_screen.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/favorites_screen.dart';
import 'package:kaawa_mobile/profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kaawa_mobile/data/coffee_stock_data.dart';

class BuyerHomeScreen extends StatefulWidget {
  final User buyer;
  const BuyerHomeScreen({super.key, required this.buyer});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> with TickerProviderStateMixin {
  late Future<List<User>> _farmersFuture;
  List<User> _allFarmers = [];
  List<User> _filteredFarmers = [];
  final _searchController = TextEditingController();
  bool _sortByDistance = false;
  Set<int> _favoriteUserIds = {};
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _farmersFuture = _getFarmers();
    _searchController.addListener(_filterFarmers);
    _loadFavorites();

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
    final favorites = await DatabaseHelper.instance.getFavorites(widget.buyer.id!);
    setState(() {
      _favoriteUserIds = favorites.map((user) => user.id!).toSet();
    });
  }

  Future<List<User>> _getFarmers() async {
    final allUsers = await DatabaseHelper.instance.getAllUsers();
    return allUsers.where((user) => user.userType == UserType.farmer).toList();
  }

  void _filterFarmers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFarmers = _allFarmers.where((farmer) {
        final nameLower = farmer.fullName.toLowerCase();
        final districtLower = farmer.district.toLowerCase();
        return nameLower.contains(query) ||
            districtLower.contains(query);
      }).toList();
    });
  }

  void _toggleSortByDistance() {
    setState(() {
      _sortByDistance = !_sortByDistance;
      if (_sortByDistance) {
        _filteredFarmers.sort((a, b) {
          final distanceA = Geolocator.distanceBetween(
            widget.buyer.latitude!,
            widget.buyer.longitude!,
            a.latitude!,
            a.longitude!,
          );
          final distanceB = Geolocator.distanceBetween(
            widget.buyer.latitude!,
            widget.buyer.longitude!,
            b.latitude!,
            b.longitude!,
          );
          return distanceA.compareTo(distanceB);
        });
      } else {
        _filteredFarmers = List.from(_allFarmers);
        _filterFarmers();
      }
    });
  }

  Future<void> _toggleFavorite(int farmerId) async {
    if (_favoriteUserIds.contains(farmerId)) {
      await DatabaseHelper.instance.removeFavorite(widget.buyer.id!, farmerId);
    } else {
      await DatabaseHelper.instance.addFavorite(widget.buyer.id!, farmerId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.buyer.fullName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FavoritesScreen(currentUser: widget.buyer),
                ),
              );
            },
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
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Available Farmers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                future: _farmersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return const Center(child: Text('Error loading farmers.'));
                  } else {
                    _allFarmers = snapshot.data ?? [];
                    _filteredFarmers = List.from(_allFarmers);
                    return FadeTransition(
                      opacity: _animation,
                      child: _filteredFarmers.isEmpty && _searchController.text.isNotEmpty
                          ? const Center(child: Text('No farmers found.'))
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.75,
                              ),
                              itemCount: _filteredFarmers.length,
                              itemBuilder: (context, index) {
                                final farmer = _filteredFarmers[index];
                                final isFavorite = _favoriteUserIds.contains(farmer.id);
                                final distance = widget.buyer.latitude != null &&
                                        widget.buyer.longitude != null &&
                                        farmer.latitude != null &&
                                        farmer.longitude != null
                                    ? Geolocator.distanceBetween(
                                        widget.buyer.latitude!,
                                        widget.buyer.longitude!,
                                        farmer.latitude!,
                                        farmer.longitude!,
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
                                          builder: (context) => ProfileScreen(currentUser: widget.buyer, profileOwner: farmer),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        AspectRatio(
                                          aspectRatio: 1,
                                          child: CircleAvatar(
                                            radius: 30,
                                            backgroundImage: farmer.profilePicturePath != null
                                                ? FileImage(File(farmer.profilePicturePath!))
                                                : null,
                                            child: farmer.profilePicturePath == null
                                                ? const Icon(Icons.person, size: 30)
                                                : null,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(farmer.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text('District: ${farmer.district}'),
                                              if (distance != null)
                                                Text('${distance.toStringAsFixed(1)} km away'),
                                            ],
                                          ),
                                        ),
                                        FutureBuilder<List<CoffeeStock>>(
                                          future: DatabaseHelper.instance.getCoffeeStock(farmer.id!),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                                child: Text('Available: ${snapshot.data!.map((s) => s.coffeeType).join(', ')}'),
                                              );
                                            } else {
                                              return const SizedBox.shrink();
                                            }
                                          },
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            IconButton(
                                              icon: Icon(isFavorite ? Icons.star : Icons.star_border, color: isFavorite ? Colors.amber : Colors.grey),
                                              onPressed: () => _toggleFavorite(farmer.id!),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.message),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChatScreen(
                                                      currentUser: widget.buyer,
                                                      otherUser: farmer,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.phone),
                                              onPressed: () => _makePhoneCall(farmer.phoneNumber),
                                            ),
                                          ],
                                        ),
                                      ],
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
