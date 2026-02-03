import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/app_user.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(FirebaseFirestore.instance);
});

class AdminRepository {
  final FirebaseFirestore _firestore;

  AdminRepository(this._firestore);

  Stream<List<AppUser>> watchPendingDrivers() {
    return _firestore
        .collection('drivers')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AppUser(
          uid: doc.id,
          role: 'driver',
          status: 'pending',
          displayName: (data['personalInfo'] as Map?)?['name'] ?? 'Unknown',
          phoneNumber: (data['personalInfo'] as Map?)?['phone'],
          photoUrl: (data['personalInfo'] as Map?)?['photoUrl'],
        );
      }).toList();
    });
  }

  Stream<List<AppUser>> watchPendingClients() {
    return _firestore
        .collection('clients')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AppUser(
          uid: doc.id,
          role: 'client',
          status: 'pending',
          displayName: (data['personalInfo'] as Map?)?['name'] ?? 'Unknown',
          phoneNumber: (data['personalInfo'] as Map?)?['phone'],
          photoUrl: (data['personalInfo'] as Map?)?['photoUrl'],
        );
      }).toList();
    });
  }

  Future<void> updateUserStatus({
    required String uid,
    required String role,
    required String newStatus,
  }) async {
    final batch = _firestore.batch();

    // 1. Update Role-Specific Collection
    if (role == 'driver') {
      batch.update(
        _firestore.collection('drivers').doc(uid),
        {'status': newStatus},
      );
    } else if (role == 'client') {
      batch.update(
        _firestore.collection('clients').doc(uid),
        {'status': newStatus},
      );
    }

    // 2. Update Central Users Collection
    batch.update(
      _firestore.collection('users').doc(uid),
      {'status': newStatus},
    );

    await batch.commit();
  }
}
