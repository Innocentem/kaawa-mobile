import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/profile_screen.dart';
import 'package:kaawa_mobile/widgets/app_avatar.dart';
import 'package:kaawa_mobile/widgets/compact_loader.dart';

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
            return Center(
              child: SizedBox(
                height: 200,
                child: const Center(child: CompactLoader(size: 28, strokeWidth: 3.0, semanticsLabel: 'Loading favorites')),
              ),
            );
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading favorites.'));
          } else {
            final favorites = snapshot.data ?? [];

            if (favorites.isEmpty) {
              return Center(
                child: Text(
                  'You have no favorites yet.\n\nAdd farmers and buyers to your favorites to see them here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).textTheme.bodySmall == null ? null : Theme.of(context).textTheme.bodySmall!.color!.withAlpha((0.7 * 255).round()),
                  ),
                ),
              );
            }

            return ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final favoriteUser = favorites[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    leading: Hero(
                      tag: favoriteUser.id != null ? 'avatar-${favoriteUser.id}' : UniqueKey(),
                      child: AppAvatar(
                        filePath: favoriteUser.profilePicturePath,
                        imageUrl: favoriteUser.profilePicturePath,
                        size: 48,
                      ),
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
