import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_button.dart';
import '../data/rating_repository.dart';

class RatingDialog extends ConsumerStatefulWidget {
  final String rideId;
  final String currentUserId;
  final String targetUserId;
  final String targetUserRole; // 'driver' or 'client'

  const RatingDialog({
    super.key,
    required this.rideId,
    required this.currentUserId,
    required this.targetUserId,
    required this.targetUserRole,
  });

  @override
  ConsumerState<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends ConsumerState<RatingDialog> {
  double _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  void _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(ratingRepositoryProvider).submitRating(
            rideId: widget.rideId,
            fromUserId: widget.currentUserId,
            toUserId: widget.targetUserId,
            rating: _rating,
            userRole: widget.targetUserRole,
            comment: _commentController.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate your Trip'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('How was your experience with the ${widget.targetUserRole}?'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
                onPressed: () {
                  setState(() => _rating = index + 1.0);
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              hintText: 'Leave a comment (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        if (_isSubmitting)
          const Center(child: CircularProgressIndicator())
        else
          AppButton(
            text: 'Submit Rating',
            onPressed: _submitRating,
          ),
      ],
    );
  }
}
