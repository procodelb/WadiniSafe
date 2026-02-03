import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  return RatingRepository(FirebaseFirestore.instance);
});

class RatingRepository {
  final FirebaseFirestore _firestore;

  RatingRepository(this._firestore);

  Future<void> submitRating({
    required String rideId,
    required String fromUserId,
    required String toUserId,
    required double rating,
    required String userRole, // 'driver' or 'client' (role of the person being rated)
    String? comment,
  }) async {
    final ratingRef = _firestore.collection('ratings').doc();

    await _firestore.runTransaction((transaction) async {
      // 1. Create Rating Document
      transaction.set(ratingRef, {
        'rideId': rideId,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'rating': rating,
        'comment': comment,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update User Aggregate
      final collectionName = userRole == 'driver' ? 'drivers' : 'clients'; // Careful here. If I rate a driver, I update 'drivers'.
      // Wait, if I am a client rating a driver, userRole should be 'driver'.
      // Let's clarify param: 'targetUserRole'

      final userRef = _firestore.collection(collectionName).doc(toUserId);
      final userDoc = await transaction.get(userRef);

      if (userDoc.exists) {
        final currentData = userDoc.data()!;
        final currentAvg = (currentData['ratingAvg'] ?? 0.0) as double; // Use double
        final currentCount = (currentData['ratingCount'] ?? 0) as int;

        final newCount = currentCount + 1;
        final newAvg = ((currentAvg * currentCount) + rating) / newCount;

        transaction.update(userRef, {
          'ratingAvg': newAvg,
          'ratingCount': newCount,
        });
      }
    });
  }
}
