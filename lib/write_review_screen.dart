import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kaawa/data/review_data.dart';
import 'package:kaawa/data/coffee_stock_data.dart';
import 'package:kaawa/data/user_data.dart' as kaawa;
import 'package:kaawa/data/supabase_service.dart';
import 'package:kaawa/widgets/app_avatar.dart';

class WriteReviewScreen extends StatefulWidget {
  final kaawa.User reviewer;
  final kaawa.User? reviewedUser;
  final CoffeeStock? coffeeStock;

  const WriteReviewScreen({
    super.key,
    required this.reviewer,
    this.reviewedUser,
    this.coffeeStock,
  }) : assert(reviewedUser != null || coffeeStock != null);

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reviewController = TextEditingController();
  double _rating = 0.0;
  bool _alreadyReviewed = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadReviewStatus();
  }

  Future<void> _loadReviewStatus() async {
    if (widget.reviewedUser != null) {
      final exists = await SupabaseService.instance.hasReviewByUser(widget.reviewer.id!, widget.reviewedUser!.id!);
      if (mounted) setState(() => _alreadyReviewed = exists);
    }
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating.')),
      );
      return;
    }
    if (_alreadyReviewed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already reviewed this.')),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      final newReview = Review(
        reviewerId: widget.reviewer.id!,
        reviewedUserId: widget.reviewedUser?.id,
        coffeeStockId: widget.coffeeStock?.id,
        rating: _rating,
        comment: _reviewController.text,
      );

      try {
        await SupabaseService.instance.insertReview(newReview);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting review: $e')),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully!')),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: theme.colorScheme.surface.withValues(alpha: 0.5)),
          ),
        ),
        title: Image.asset(
          'assets/icons/pngwing.png',
          height: 32,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.05),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Write a Review',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (widget.reviewedUser != null) ...[
                    AppAvatar(
                      filePath: widget.reviewedUser!.profilePicturePath,
                      imageUrl: widget.reviewedUser!.profilePicturePath,
                      size: 100,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.reviewedUser!.fullName,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.reviewedUser!.userType == kaawa.UserType.farmer ? 'Farmer' : 'Buyer',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                    ),
                  ] else if (widget.coffeeStock != null) ...[
                     // Display coffee stock info if reviewedUser is null
                    const Icon(Icons.inventory, size: 80),
                    const SizedBox(height: 16),
                    Text(
                      widget.coffeeStock!.coffeeType,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Text('Product Review', style: TextStyle(fontSize: 16)),
                  ],
                  const SizedBox(height: 32),
                  const Text('How was your experience?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      final isSelected = _rating >= value;
                      return IconButton(
                        iconSize: 40,
                        onPressed: _alreadyReviewed ? null : () => setState(() => _rating = value.toDouble()),
                        icon: Icon(
                          isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: isSelected ? Colors.amber : theme.disabledColor,
                        ),
                      );
                    }),
                  ),
                  if (_alreadyReviewed) ...[
                    const SizedBox(height: 8),
                    Text(
                      'You already reviewed this user.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _reviewController,
                    readOnly: _alreadyReviewed,
                    decoration: InputDecoration(
                      hintText: 'Share your thoughts about this user...',
                      labelText: 'Review comment',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    maxLines: 5,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your review';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_alreadyReviewed || _isSubmitting) ? null : _submitReview,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator.adaptive()
                          : const Text('Submit Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
