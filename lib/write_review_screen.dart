import 'package:flutter/material.dart';
import 'package:kaawa/data/review_data.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/data/supabase_service.dart';

class WriteReviewScreen extends StatefulWidget {
  final kaawa.User reviewer;
  final kaawa.User reviewedUser;

  const WriteReviewScreen({super.key, required this.reviewer, required this.reviewedUser});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reviewController = TextEditingController();
  double _rating = 3.0;
  bool _alreadyReviewed = false;

  @override
  void initState() {
    super.initState();
    _loadReviewStatus();
  }

  Future<void> _loadReviewStatus() async {
    final exists = await SupabaseService.instance.hasReviewByUser(widget.reviewer.id!, widget.reviewedUser.id!);
    if (!mounted) return;
    setState(() => _alreadyReviewed = exists);
  }

  Future<void> _submitReview() async {
    if (_alreadyReviewed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already reviewed this user.')),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      final newReview = Review(
        reviewerId: widget.reviewer.id!,
        reviewedUserId: widget.reviewedUser.id!,
        rating: _rating,
        comment: _reviewController.text,
      );

      try {
        await SupabaseService.instance.insertReview(newReview);
      } catch (e) {
        if (!mounted) return;
        // In Supabase, the unique constraint (reviewer_id, reviewed_user_id) will throw an error
        setState(() => _alreadyReviewed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already reviewed this user.')),
        );
        return;
      }

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
              if (_alreadyReviewed) ...[
                const SizedBox(height: 6),
                Text('You already reviewed this user.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (index) {
                  final value = index + 1;
                  final isSelected = _rating >= value;
                  return IconButton(
                    tooltip: '$value star${value == 1 ? '' : 's'}',
                    onPressed: () => setState(() => _rating = value.toDouble()),
                    icon: Icon(
                      isSelected ? Icons.star : Icons.star_border,
                      color: isSelected ? Colors.amber.shade700 : Theme.of(context).disabledColor,
                    ),
                  );
                }),
              ),
              Text('$_rating / 5', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
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
                onPressed: _alreadyReviewed ? null : _submitReview,
                child: const Text('Submit Review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
