import 'package:kaawa/utils/date_utils.dart';

class Review {
  final int? id;
  final String reviewerId;
  final String reviewedUserId;
  final double rating;
  final String comment;
  final DateTime? timestamp;

  Review({
    this.id,
    required this.reviewerId,
    required this.reviewedUserId,
    required this.rating,
    required this.comment,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'reviewer_id': reviewerId,
      'reviewed_user_id': reviewedUserId,
      'rating': rating,
      'review_text': comment,
    };
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'],
      reviewerId: map['reviewer_id'] ?? '',
      reviewedUserId: map['reviewed_user_id'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      comment: map['review_text'] ?? '',
      timestamp: parseDateSafe(map['created_at']),
    );
  }
}
