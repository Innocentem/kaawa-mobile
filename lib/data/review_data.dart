import 'package:kaawa/utils/date_utils.dart';

class Review {
  final int? id;
  final String reviewerId;
  final String? reviewedUserId;
  final String? coffeeStockId;
  final double rating;
  final String comment;
  final DateTime? timestamp;

  Review({
    this.id,
    required this.reviewerId,
    this.reviewedUserId,
    this.coffeeStockId,
    required this.rating,
    required this.comment,
    this.timestamp,
  }) : assert(reviewedUserId != null || coffeeStockId != null);

  Map<String, dynamic> toMap() {
    return {
      'reviewer_id': reviewerId,
      if (reviewedUserId != null) 'reviewed_user_id': reviewedUserId,
      if (coffeeStockId != null) 'coffee_stock_id': coffeeStockId,
      'rating': rating,
      'review_text': comment,
    };
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'],
      reviewerId: map['reviewer_id'] ?? '',
      reviewedUserId: map['reviewed_user_id']?.toString(),
      coffeeStockId: map['coffee_stock_id']?.toString(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      comment: map['review_text'] ?? '',
      timestamp: parseDateSafe(map['created_at']),
    );
  }
}
