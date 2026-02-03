
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kaawa_mobile/chat_screen.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/favorites_screen.dart';
import 'package:kaawa_mobile/profile_screen.dart';
import 'package:kaawa_mobile/theme/app_colors.dart';
import 'package:kaawa_mobile/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';

class BuyerHomeScreen extends StatefulWidget {
  final User buyer;
  const BuyerHomeScreen({super.key, required this.buyer});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  late Future<List<User>> _farmersFuture;
  List<User> _allFarmers = [];
  List<User> _filteredFarmers = [];
  final _searchController = TextEditingController();
  bool _sortByDistance = false;
  Set<int> _favoriteUserIds = {};

  @override
  void initState() {
    super.initState();
    _farmersFuture = _getFarmers();
    _searchController.addListener(_filterFarmers);
    _loadFavorites();
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
        final coffeeTypeLower = farmer.coffeeType?.toLowerCase() ?? '';
        return nameLower.contains(query) ||
            districtLower.contains(query) ||
            coffeeTypeLower.contains(query);
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
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('Welcome, ${widget.buyer.fullName}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            tooltip: 'Favorites',
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
            tooltip: 'Profile',
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
            Text(
              'Available Farmers',
              style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search farmers',
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
                future: _farmersFuture,
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
                            'Error loading farmers',
                            style: AppTypography.titleLarge,
                          ),
                        ],
                      ),
                    );
                  } else {
                    _allFarmers = snapshot.data ?? [];
                    _filteredFarmers = List.from(_allFarmers);
                    return _filteredFarmers.isEmpty && _searchController.text.isNotEmpty
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
                                  'No farmers found',
                                  style: AppTypography.titleLarge,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
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
                                        builder: (context) => ProfileScreen(currentUser: widget.buyer, profileOwner: farmer),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 30,
                                                  backgroundColor: AppColors.primaryBrown.withOpacity(0.1),
                                                  backgroundImage: farmer.profilePicturePath != null
                                                      ? FileImage(File(farmer.profilePicturePath!))
                                                      : null,
                                                  child: farmer.profilePicturePath == null
                                                      ? const Icon(Icons.person, color: AppColors.primaryBrown, size: 30)
                                                      : null,
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        farmer.fullName,
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
                                                            farmer.district,
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
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    isFavorite ? Icons.star : Icons.star_border,
                                                    color: isFavorite ? Colors.amber : AppColors.textLight,
                                                  ),
                                                  onPressed: () => _toggleFavorite(farmer.id!),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            // Coffee info
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryBrown.withOpacity(0.05),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.coffee,
                                                        size: 20,
                                                        color: AppColors.primaryBrown,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        farmer.coffeeType ?? 'N/A',
                                                        style: AppTypography.bodyMedium.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.primaryBrown,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.inventory_2,
                                                        size: 18,
                                                        color: AppColors.textMedium,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${farmer.quantity ?? 0} Kgs',
                                                        style: AppTypography.bodySmall.copyWith(
                                                          color: AppColors.textDark,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primaryGreen,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      'UGX ${farmer.pricePerKg ?? 0}/Kg',
                                                      style: AppTypography.labelMedium.copyWith(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (farmer.coffeePicturePath != null)
                                        ClipRRect(
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                          child: Image.file(
                                            File(farmer.coffeePicturePath!),
                                            height: 200,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      const Divider(height: 1),
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
                                                      currentUser: widget.buyer,
                                                      otherUser: farmer,
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
                                              onPressed: () => _makePhoneCall(farmer.phoneNumber),
                                            ),
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
            ),
          ],
        ),
      ),
    );
  }
}
