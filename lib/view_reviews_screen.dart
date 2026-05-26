import 'package:flutter/material.dart';
import 'package:kaawa/data/review_data.dart';
import 'package:kaawa/data/coffee_stock_data.dart';
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/widgets/compact_loader.dart';
import 'package:kaawa/widgets/app_avatar.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;

class ViewReviewsScreen extends StatefulWidget {
  final kaawa.User reviewedUser;
  // optional: the currently logged-in user viewing the reviews
  final kaawa.User? currentUser;
  // callback to open a profile for a given reviewer (avoids circular import)
  final void Function(kaawa.User reviewer)? onOpenProfile;

  const ViewReviewsScreen({super.key, required this.reviewedUser, this.currentUser, this.onOpenProfile});

  @override
  State<ViewReviewsScreen> createState() => _ViewReviewsScreenState();
}

class _ViewReviewsScreenState extends State<ViewReviewsScreen> {
  // Each item will be a map: { 'review': Review, 'reviewer': User?, 'coffeeStock': CoffeeStock? }
  late Future<List<Map<String, dynamic>>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _getReviewsWithUsers();
  }

  Future<List<Map<String, dynamic>>> _getReviewsWithUsers() async {
    // use Supabase service
    return await SupabaseService.instance.getReviewsForUserWithReviewers(widget.reviewedUser.id!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/icons/pngwing.png',
          height: 32,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _reviewsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: SizedBox(height: 160, child: Center(child: CompactLoader(size: 28, strokeWidth: 3.0, semanticsLabel: 'Loading reviews'))));
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading reviews.'));
          } else {
            final entries = snapshot.data ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'User Reviews',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Reviews for ${widget.reviewedUser.fullName}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(child: Text('No reviews yet.'))
                      : ListView.builder(
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                      final entry = entries[index];
                      final review = entry['review'] as Review;
                      final reviewer = entry['reviewer'] as kaawa.User?;
                      final coffeeStock = entry['coffeeStock'] as CoffeeStock?;
                      final rating = review.rating;
                      final reviewText = review.comment;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: reviewer == null
                                        ? null
                                        : () {
                                            if (widget.onOpenProfile != null) {
                                              widget.onOpenProfile!(reviewer);
                                            }
                                          },
                                    child: Hero(
                                      tag: reviewer != null && reviewer.id != null ? 'avatar-${reviewer.id}' : UniqueKey(),
                                      child: Material(type: MaterialType.transparency, child: AppAvatar(filePath: reviewer?.profilePicturePath, imageUrl: reviewer?.profilePicturePath, size: 40)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: reviewer == null
                                          ? null
                                          : () {
                                              if (widget.onOpenProfile != null) {
                                                widget.onOpenProfile!(reviewer);
                                              }
                                            },
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(reviewer?.fullName ?? 'Unknown', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                          if (coffeeStock != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Listing: ${coffeeStock.coffeeType}',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Row(
                                            children: List.generate(5, (starIndex) {
                                              return Icon(
                                                starIndex < rating ? Icons.star : Icons.star_border,
                                                color: IconTheme.of(context).color ?? theme.colorScheme.secondary,
                                                size: 18,
                                              );
                                            }),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(reviewText),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
