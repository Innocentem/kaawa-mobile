import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/review_data.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/widgets/shimmer_skeleton.dart';
import 'package:kaawa_mobile/widgets/app_avatar.dart';

class ViewReviewsScreen extends StatefulWidget {
  final User reviewedUser;
  // optional: the currently logged-in user viewing the reviews
  final User? currentUser;
  // callback to open a profile for a given reviewer (avoids circular import)
  final void Function(User reviewer)? onOpenProfile;

  const ViewReviewsScreen({super.key, required this.reviewedUser, this.currentUser, this.onOpenProfile});

  @override
  State<ViewReviewsScreen> createState() => _ViewReviewsScreenState();
}

class _ViewReviewsScreenState extends State<ViewReviewsScreen> {
  // Each item will be a map: { 'review': Review, 'reviewer': User? }
  late Future<List<Map<String, dynamic>>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _getReviewsWithUsers();
  }

  Future<List<Map<String, dynamic>>> _getReviewsWithUsers() async {
    // use optimized JOIN helper
    final rows = await DatabaseHelper.instance.getReviewsWithReviewers(widget.reviewedUser.id!);
    // each row: { 'review': {id, reviewerId, reviewedUserId, rating, reviewText}, 'reviewer': User? }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reviews for ${widget.reviewedUser.fullName}'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _reviewsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: SizedBox(height: 160, child: ShimmerSkeleton.rect()));
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading reviews.'));
          } else {
            final entries = snapshot.data ?? [];
            return entries.isEmpty
                ? const Center(child: Text('No reviews yet.'))
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final reviewMap = entry['review'] as Map<String, dynamic>;
                      final reviewer = entry['reviewer'] as dynamic; // may be User or null
                      final ratingVal = reviewMap['rating'];
                      final rating = ratingVal is num ? ratingVal.toDouble() : double.tryParse(ratingVal?.toString() ?? '') ?? 0.0;
                      final reviewText = reviewMap['reviewText']?.toString() ?? '';
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
                                      child: AppAvatar(filePath: reviewer?.profilePicturePath, imageUrl: reviewer?.profilePicturePath, size: 40),
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
                                          Text(reviewer?.fullName ?? 'Unknown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: List.generate(5, (starIndex) {
                                              return Icon(
                                                starIndex < rating ? Icons.star : Icons.star_border,
                                                color: Colors.amber,
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
                  );
          }
        },
      ),
    );
  }
}
