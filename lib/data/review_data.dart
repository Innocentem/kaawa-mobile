
class Review {
  final int? id;
  final int reviewerId;
  final int reviewedUserId;
  final double rating;
  final String reviewText;

  Review({
    this.id,
    required this.reviewerId,
    required this.reviewedUserId,
    required this.rating,
    required this.reviewText,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reviewerId': reviewerId,
      'reviewedUserId': reviewedUserId,
      'rating': rating,
      'reviewText': reviewText,
    };
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'],
      reviewerId: map['reviewerId'],
      reviewedUserId: map['reviewedUserId'],
      rating: map['rating'],
      reviewText: map['reviewText'],
    );
  }
}
