
import 'package:flutter/material.dart';
import 'package:kaawa_mobile/data/review_data.dart';
import 'package:kaawa_mobile/data/user_data.dart';
import 'package:kaawa_mobile/data/database_helper.dart';

class WriteReviewScreen extends StatefulWidget {
  final User reviewer;
  final User reviewedUser;

  const WriteReviewScreen({super.key, required this.reviewer, required this.reviewedUser});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reviewController = TextEditingController();
  double _rating = 3.0;

  Future<void> _submitReview() async {
    if (_formKey.currentState!.validate()) {
      final newReview = Review(
        reviewerId: widget.reviewer.id!,
        reviewedUserId: widget.reviewedUser.id!,
        rating: _rating,
        reviewText: _reviewController.text,
      );

      await DatabaseHelper.instance.insertReview(newReview);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully!')),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Write a review for ${widget.reviewedUser.fullName}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              const Text('Rating', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Slider(
                value: _rating,
                onChanged: (newRating) {
                  setState(() => _rating = newRating);
                },
                min: 1,
                max: 5,
                divisions: 4,
                label: _rating.toString(),
              ),
              TextFormField(
                controller: _reviewController,
                decoration: const InputDecoration(
                  labelText: 'Review',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your review';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitReview,
                child: const Text('Submit Review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
