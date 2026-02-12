import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/review_data.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';
import 'package:kaawa_mobile/widgets/shimmer_skeleton.dart';

class ViewReviewsScreen extends StatefulWidget {
  final User reviewedUser;

  const ViewReviewsScreen({super.key, required this.reviewedUser});

  @override
  State<ViewReviewsScreen> createState() => _ViewReviewsScreenState();
}

class _ViewReviewsScreenState extends State<ViewReviewsScreen> {
  late Future<List<Review>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _getReviews();
  }

  Future<List<Review>> _getReviews() async {
    return await DatabaseHelper.instance.getReviews(widget.reviewedUser.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reviews for ${widget.reviewedUser.fullName}'),
      ),
      body: FutureBuilder<List<Review>>(
        future: _reviewsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: SizedBox(height: 160, child: ShimmerSkeleton.rect()));
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading reviews.'));
          } else {
            final reviews = snapshot.data ?? [];
            return reviews.isEmpty
                ? const Center(child: Text('No reviews yet.'))
                : ListView.builder(
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: List.generate(5, (starIndex) {
                                  return Icon(
                                    starIndex < review.rating ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                  );
                                }),
                              ),
                              const SizedBox(height: 8),
                              Text(review.reviewText),
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
