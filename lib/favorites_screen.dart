import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/widgets/shimmer_skeleton.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/profile_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final kaawa.User currentUser;
  const FavoritesScreen({super.key, required this.currentUser});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<kaawa.User>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _favoritesFuture = SupabaseService.instance.getFavorites(widget.currentUser.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.8),
              elevation: 0,
              foregroundColor: theme.colorScheme.onPrimary,
              title: Image.asset(
                'assets/icons/pngwing.png',
                height: 32,
                fit: BoxFit.contain,
              ),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'My Favorites',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<kaawa.User>>(
              future: _favoritesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ShimmerSkeleton.rect(height: 72, borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Error loading favorites.'));
                } else {
                  final favorites = snapshot.data ?? [];

                  if (favorites.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.favorite_border, size: 64, color: theme.hintColor.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text(
                              'You have no favorites yet.',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add farmers and buyers to your favorites to see them here.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: favorites.length,
                    itemBuilder: (context, index) {
                      final user = favorites[index];
                      return _buildFavoriteCard(user, theme);
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(kaawa.User user, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: AppAvatar(
          filePath: user.profilePicturePath,
          size: 48,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => ProfileScreen(currentUser: widget.currentUser, profileOwner: user),
              ),
            );
          },
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(user.district ?? 'No district'),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: Colors.red),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Remove favorite'),
                content: Text('Are you sure you want to remove ${user.fullName} from favorites?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
                ],
              ),
            );
            if (confirmed == true) {
              await SupabaseService.instance.removeFavorite(widget.currentUser.id!, user.id!);
              _refresh();
            }
          },
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (c) => ProfileScreen(currentUser: widget.currentUser, profileOwner: user),
            ),
          );
        },
      ),
    );
  }
}
