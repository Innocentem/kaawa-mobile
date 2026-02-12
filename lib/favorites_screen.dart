import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/profile_screen.dart';
import 'package:kaawa_mobile/widgets/app_avatar.dart';
import 'package:kaawa_mobile/widgets/shimmer_skeleton.dart';

class FavoritesScreen extends StatefulWidget {
  final User currentUser;

  const FavoritesScreen({super.key, required this.currentUser});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<User>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = _getFavorites();
  }

  Future<List<User>> _getFavorites() async {
    return await DatabaseHelper.instance.getFavorites(widget.currentUser.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
      ),
      body: FutureBuilder<List<User>>(
        future: _favoritesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: SizedBox(height: 200, child: ShimmerSkeleton.rect()));
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading favorites.'));
          } else {
            final favorites = snapshot.data ?? [];
            return favorites.isEmpty
                ? const Center(
                    child: Text(
                      'You have no favorites yet.\n\nAdd farmers and buyers to your favorites to see them here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: favorites.length,
                    itemBuilder: (context, index) {
                      final favoriteUser = favorites[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: ListTile(
                          leading: AppAvatar(
                            filePath: favoriteUser.profilePicturePath,
                            imageUrl: favoriteUser.profilePicturePath, // support both file paths and remote urls
                            size: 48,
                          ),
                          title: Text(favoriteUser.fullName),
                          subtitle: Text(favoriteUser.district),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  currentUser: widget.currentUser,
                                  profileOwner: favoriteUser,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
          }
        },
      ),
    );
  }
}
