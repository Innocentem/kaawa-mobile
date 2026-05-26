import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kaawa/data/coffee_stock_data.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/chat_screen.dart';
import 'package:kaawa/view_reviews_screen.dart';
import 'package:kaawa/profile_screen.dart';

class InterestedBuyersScreen extends StatefulWidget {
  final CoffeeStock stock;
  final kaawa.User currentUser;
  const InterestedBuyersScreen({super.key, required this.stock, required this.currentUser});

  @override
  State<InterestedBuyersScreen> createState() => _InterestedBuyersScreenState();
}

class _InterestedBuyersScreenState extends State<InterestedBuyersScreen> {
  late Future<List<kaawa.User>> _buyersFuture;

  @override
  void initState() {
    super.initState();
    _refreshBuyers();
  }

  void _refreshBuyers() {
    setState(() {
      _buyersFuture = SupabaseService.instance.getInterestedBuyersForStock(widget.stock.id!);
    });
    SupabaseService.instance.markInterestsAsSeen(widget.stock.id!).then((_) {
      // Refreshing counts elsewhere will be handled by streams
    });
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Container(height: 80, color: Colors.grey[200]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AppBar(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.7),
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
        body: RefreshIndicator(
          onRefresh: () async => _refreshBuyers(),
          edgeOffset: MediaQuery.of(context).padding.top + kToolbarHeight,
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interested Buyers',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.stock.coffeeType,
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary.withAlpha((0.7 * 255).round())),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<kaawa.User>>(
                  future: _buyersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildShimmerList();
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: ${snapshot.error}'),
                            ElevatedButton(onPressed: _refreshBuyers, child: const Text('Retry')),
                          ],
                        ),
                      );
                    }
                    final buyers = snapshot.data ?? [];
                    if (buyers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: theme.hintColor.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            const Text('No interested buyers yet.'),
                            const SizedBox(height: 8),
                            TextButton(onPressed: _refreshBuyers, child: const Text('Refresh')),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: buyers.length,
                      itemBuilder: (context, index) {
                        final b = buyers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            leading: AppAvatar(
                              filePath: b.profilePicturePath,
                              size: 48,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) => ProfileScreen(currentUser: widget.currentUser, profileOwner: b),
                                  ),
                                );
                              },
                            ),
                            title: Text(b.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(b.district ?? 'No district'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.star_outline),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (c) => ViewReviewsScreen(
                                          reviewedUser: b,
                                          currentUser: widget.currentUser,
                                          onOpenProfile: (reviewer) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (c) => ProfileScreen(currentUser: widget.currentUser, profileOwner: reviewer),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (c) => ChatScreen(currentUser: widget.currentUser, otherUser: b),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
