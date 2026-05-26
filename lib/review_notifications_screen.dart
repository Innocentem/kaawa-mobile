import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/data/review_data.dart';
import 'package:kaawa/data/coffee_stock_data.dart';
import 'package:kaawa/widgets/shimmer_skeleton.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/profile_screen.dart';
import 'package:kaawa/chat_screen.dart';

class ReviewNotificationsScreen extends StatefulWidget {
  final kaawa.User currentUser;
  const ReviewNotificationsScreen({super.key, required this.currentUser});

  @override
  State<ReviewNotificationsScreen> createState() => _ReviewNotificationsScreenState();
}

class _ReviewNotificationsScreenState extends State<ReviewNotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _notificationsFuture = SupabaseService.instance.getReviewNotifications(widget.currentUser.id!);
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
              'Review notifications',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: 5,
                    itemBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ShimmerSkeleton.rect(height: 100, borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading review notifications.'));
                }
                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return const Center(child: Text('No reviews yet.'));
                }

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final notification = entry['notification'] as Map<String, dynamic>;
                      final review = Review.fromMap(entry['review'] as Map<String, dynamic>);
                      final reviewer = entry['reviewer'] as kaawa.User?;
                      final coffeeStock = entry['coffeeStock'] as CoffeeStock?;
                      final rating = review.rating;

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppAvatar(
                                filePath: reviewer?.profilePicturePath,
                                size: 40,
                                onTap: reviewer == null
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (c) => ProfileScreen(currentUser: widget.currentUser, profileOwner: reviewer),
                                          ),
                                        );
                                      },
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          reviewer?.fullName ?? 'Unknown',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 16),
                                            Text(
                                              rating.toStringAsFixed(1),
                                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (coffeeStock != null) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Listing: ${coffeeStock.coffeeType}',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      review.comment.isEmpty ? 'No comment provided.' : review.comment,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: reviewer == null
                                              ? null
                                              : () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (c) => ChatScreen(
                                                        currentUser: widget.currentUser,
                                                        otherUser: reviewer,
                                                      ),
                                                    ),
                                                  );
                                                },
                                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                          label: const Text('Chat'),
                                        ),
                                        if (notification['isRead'] == false) ...[
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: () async {
                                              await SupabaseService.instance.markReviewNotificationRead(notification['id']);
                                              _refresh();
                                            },
                                            child: const Text('Mark as read'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
