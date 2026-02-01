
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kaawa_mobile/chat_screen.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/favorites_screen.dart';
import 'package:kaawa_mobile/manage_stock_screen.dart';
import 'package:kaawa_mobile/profile_screen.dart';
import 'package:kaawa_mobile/theme/app_colors.dart';
import 'package:kaawa_mobile/theme/app_typography.dart';
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
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('Welcome, ${widget.farmer.fullName}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            tooltip: 'Favorites',
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
            tooltip: 'Profile',
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
            // Stock management card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: AppColors.primaryGreen.withOpacity(0.1),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageStockScreen(farmer: widget.farmer),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manage Your Stock',
                              style: AppTypography.titleLarge.copyWith(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Update inventory and pricing',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Available Buyers',
              style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search buyers',
                hintText: 'Search by name, district, or coffee type',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            // Sort button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.sort),
                label: Text(
                  _sortByDistance ? 'Sort by Name' : 'Sort by Distance',
                  style: AppTypography.button,
                ),
                onPressed: _toggleSortByDistance,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<User>>(
                future: _buyersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBrown),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 60,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading buyers',
                            style: AppTypography.titleLarge,
                          ),
                        ],
                      ),
                    );
                  } else {
                    _allBuyers = snapshot.data ?? [];
                    _filteredBuyers = List.from(_allBuyers);
                    return _filteredBuyers.isEmpty && _searchController.text.isNotEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.search_off,
                                  size: 60,
                                  color: AppColors.textLight,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No buyers found',
                                  style: AppTypography.titleLarge,
                                ),
                              ],
                            ),
                          )
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
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProfileScreen(currentUser: widget.farmer, profileOwner: buyer),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 30,
                                              backgroundColor: AppColors.primaryBrown.withOpacity(0.1),
                                              backgroundImage: buyer.profilePicturePath != null
                                                  ? FileImage(File(buyer.profilePicturePath!))
                                                  : null,
                                              child: buyer.profilePicturePath == null
                                                  ? const Icon(Icons.person, color: AppColors.primaryBrown, size: 30)
                                                  : null,
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    buyer.fullName,
                                                    style: AppTypography.titleLarge.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.location_on,
                                                        size: 14,
                                                        color: AppColors.textMedium,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        buyer.district,
                                                        style: AppTypography.bodySmall.copyWith(
                                                          color: AppColors.textMedium,
                                                        ),
                                                      ),
                                                      if (distance != null) ...[
                                                        const SizedBox(width: 12),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.primaryGreen.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Text(
                                                            '${distance.toStringAsFixed(1)} km',
                                                            style: AppTypography.labelSmall.copyWith(
                                                              color: AppColors.primaryGreen,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.coffee,
                                                        size: 14,
                                                        color: AppColors.primaryBrown,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          'Seeking: ${buyer.coffeeTypeSought}',
                                                          style: AppTypography.bodySmall.copyWith(
                                                            color: AppColors.textDark,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                isFavorite ? Icons.star : Icons.star_border,
                                                color: isFavorite ? Colors.amber : AppColors.textLight,
                                              ),
                                              onPressed: () => _toggleFavorite(buyer.id!),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Divider(height: 1),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Expanded(
                                              child: TextButton.icon(
                                                icon: const Icon(Icons.message, size: 18),
                                                label: const Text('Message'),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: AppColors.primaryBrown,
                                                ),
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
                                            ),
                                            Container(
                                              width: 1,
                                              height: 24,
                                              color: AppColors.beige,
                                            ),
                                            Expanded(
                                              child: TextButton.icon(
                                                icon: const Icon(Icons.phone, size: 18),
                                                label: const Text('Call'),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: AppColors.primaryGreen,
                                                ),
                                                onPressed: () => _makePhoneCall(buyer.phoneNumber),
                                              ),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
