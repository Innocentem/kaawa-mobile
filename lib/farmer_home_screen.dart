
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kaawa_mobile/chat_screen.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/favorites_screen.dart';
import 'package:kaawa_mobile/manage_stock_screen.dart';
import 'package:kaawa_mobile/profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class FarmerHomeScreen extends StatefulWidget {
  final User farmer;
  const FarmerHomeScreen({super.key, required this.farmer});

  @override
  State<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends State<FarmerHomeScreen> {
  late Future<List<User>> _buyersFuture;
  List<User> _allBuyers = [];
  List<User> _filteredBuyers = [];
  final _searchController = TextEditingController();
  bool _sortByDistance = false;
  Set<int> _favoriteUserIds = {};

  @override
  void initState() {
    super.initState();
    _buyersFuture = _getBuyers();
    _searchController.addListener(_filterBuyers);
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await DatabaseHelper.instance.getFavorites(widget.farmer.id!);
    setState(() {
      _favoriteUserIds = favorites.map((user) => user.id!).toSet();
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
        final coffeeTypeSoughtLower = buyer.coffeeTypeSought?.toLowerCase() ?? '';
        return nameLower.contains(query) ||
            districtLower.contains(query) ||
            coffeeTypeSoughtLower.contains(query);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.farmer.fullName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FavoritesScreen(currentUser: widget.farmer),
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
                  builder: (context) => ProfileScreen(currentUser: widget.farmer, profileOwner: widget.farmer),
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
            ElevatedButton.icon(
              icon: const Icon(Icons.inventory),
              label: const Text('Manage Your Stock'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManageStockScreen(farmer: widget.farmer),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('Available Buyers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by name, district, or coffee type',
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
                    return _filteredBuyers.isEmpty && _searchController.text.isNotEmpty
                        ? const Center(child: Text('No buyers found.'))
                        : ListView.builder(
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
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProfileScreen(currentUser: widget.farmer, profileOwner: buyer),
                                      ),
                                    );
                                  },
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: buyer.profilePicturePath != null
                                          ? FileImage(File(buyer.profilePicturePath!))
                                          : null,
                                      child: buyer.profilePicturePath == null
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                    title: Text(buyer.fullName),
                                    subtitle: Text(
                                        'District: ${buyer.district}\nSeeking: ${buyer.coffeeTypeSought}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (distance != null)
                                          Text('${distance.toStringAsFixed(1)} km'),
                                        IconButton(
                                          icon: Icon(isFavorite ? Icons.star : Icons.star_border),
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
                                  ),
                                ),
                              );
                            },
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
