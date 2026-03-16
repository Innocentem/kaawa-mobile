import 'package:flutter/material.dart';
import 'package:kaawa/data/database_helper.dart';
import 'package:kaawa/data/user_data.dart';
import 'package:kaawa/profile_screen.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/widgets/compact_loader.dart';

class ReviewNotificationsScreen extends StatefulWidget {
  final User currentUser;
  const ReviewNotificationsScreen({super.key, required this.currentUser});

  @override
  State<ReviewNotificationsScreen> createState() => _ReviewNotificationsScreenState();
}

class _ReviewNotificationsScreenState extends State<ReviewNotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
  }

  Future<List<Map<String, dynamic>>> _loadNotifications() async {
    final rows = await DatabaseHelper.instance.getReviewNotifications(widget.currentUser.id!);
    final hasUnread = rows.any((row) => (row['notification'] as Map<String, dynamic>)['isRead'] == 0);
    if (hasUnread) {
      await DatabaseHelper.instance.markAllReviewNotificationsRead(widget.currentUser.id!);
    }
    return rows;
  }

  Widget _buildStars(BuildContext context, double rating) {
    final filled = rating.round().clamp(0, 5);
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < filled ? Icons.star : Icons.star_border,
          size: 16,
          color: Colors.amber.shade700,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review notifications')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: SizedBox(height: 160, child: Center(child: CompactLoader(size: 28, strokeWidth: 3.0, semanticsLabel: 'Loading notifications'))));
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading review notifications.'));
          }
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(child: Text('No reviews yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final notification = entry['notification'] as Map<String, dynamic>;
              final review = entry['review'] as Map<String, dynamic>;
              final reviewer = entry['reviewer'] as User?;
              final ratingVal = review['rating'];
              final rating = ratingVal is num ? ratingVal.toDouble() : double.tryParse(ratingVal?.toString() ?? '') ?? 0.0;
              final createdAt = notification['createdAt']?.toString();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: reviewer == null
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileScreen(
                                      currentUser: widget.currentUser,
                                      profileOwner: reviewer,
                                    ),
                                  ),
                                );
                              },
                        child: AppAvatar(
                          filePath: reviewer?.profilePicturePath,
                          imageUrl: reviewer?.profilePicturePath,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reviewer?.fullName ?? 'Unknown reviewer',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            _buildStars(context, rating),
                            const SizedBox(height: 6),
                            Text(review['reviewText']?.toString() ?? ''),
                            if (createdAt != null) ...[
                              const SizedBox(height: 6),
                              Text(createdAt.replaceFirst('T', ' ').split('.').first, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

