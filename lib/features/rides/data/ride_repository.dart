import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepository(FirebaseFirestore.instance);
});

class RideRepository {
  final FirebaseFirestore _firestore;

  RideRepository(this._firestore);

  // 1. Create Ride Request
  Future<String> requestRide({
    required String clientId,
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    String? vehicleType,
  }) async {
    final geo = GeoFlutterFire();
    final pickupPoint = geo.point(latitude: pickupLat, longitude: pickupLng);

    final docRef = await _firestore.collection('rides').add({
      'clientId': clientId,
      'driverId': null,
      'status': 'requested',
      'vehicleType': vehicleType,
      'pickup': {
        'lat': pickupLat,
        'lng': pickupLng,
        'geohash': pickupPoint.hash,
        'address': pickupAddress,
      },
      'dropoff': {
        'lat': dropoffLat,
        'lng': dropoffLng,
        'address': dropoffAddress,
      },
      'timestamps': {
        'created': FieldValue.serverTimestamp(),
      },
    });
    return docRef.id;
  }

  // 2. Listen to Available Rides (For Drivers)
  // Query rides with status 'requested' near driver
  Stream<List<DocumentSnapshot>> getNearbyRequests({
    required double lat,
    required double lng,
    required double radiusInKm,
    String? vehicleType,
  }) {
    final geo = GeoFlutterFire();
    final center = geo.point(latitude: lat, longitude: lng);
    Query collectionRef =
        _firestore.collection('rides').where('status', isEqualTo: 'requested');

    if (vehicleType != null) {
      // Assuming rides store vehicleType preference. If null, any vehicle type is allowed.
      // But typically, a client requests a SPECIFIC vehicle type.
      // So we should match the ride's requested vehicleType with the driver's vehicleType.
      // However, Firestore "where" clauses can be restrictive with GeoFlutterFire.
      // GeoFlutterFire uses geohashes and range queries. Adding another inequality filter might be tricky if not careful,
      // but 'isEqualTo' is usually fine.

      // WAIT: If the client requests a specific vehicle type, the RIDE document should have it.
      // And we filter rides where ride.vehicleType == driver.vehicleType.

      // Let's assume requestRide saves 'vehicleType'.
      // I need to check requestRide again.

      collectionRef =
          collectionRef.where('vehicleType', isEqualTo: vehicleType);
    }

    return geo.collection(collectionRef: collectionRef).within(
          center: center,
          radius: radiusInKm,
          field: 'pickup',
          strictMode: true,
        );
  }

  // 3. Accept Ride
  Future<void> acceptRide(
      {required String rideId, required String driverId}) async {
    // Transaction to ensure atomicity
    await _firestore.runTransaction((transaction) async {
      final rideRef = _firestore.collection('rides').doc(rideId);
      final snapshot = await transaction.get(rideRef);

      if (!snapshot.exists) throw Exception("Ride does not exist");
      if (snapshot.get('status') != 'requested')
        throw Exception("Ride already taken");

      transaction.update(rideRef, {
        'driverId': driverId,
        'status': 'accepted',
        'timestamps.accepted': FieldValue.serverTimestamp(),
      });

      // Update Driver status to active
      final driverRef = _firestore.collection('drivers').doc(driverId);
      transaction.update(driverRef, {
        'activeRideId': rideId,
      });
    });
  }

  // 4. Update Ride Status
  Future<void> updateRideStatus({
    required String rideId,
    required String status,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
    };
    if (status == 'in_progress') {
      updates['timestamps.started'] = FieldValue.serverTimestamp();
    } else if (status == 'completed') {
      updates['timestamps.completed'] = FieldValue.serverTimestamp();
    }

    await _firestore.collection('rides').doc(rideId).update(updates);
  }

  // 5. Complete Ride
  Future<void> completeRide(
      {required String rideId, required String driverId}) async {
    final batch = _firestore.batch();

    final rideRef = _firestore.collection('rides').doc(rideId);
    batch.update(rideRef, {
      'status': 'completed',
      'timestamps.completed': FieldValue.serverTimestamp(),
    });

    final driverRef = _firestore.collection('drivers').doc(driverId);
    batch.update(driverRef, {
      'activeRideId': FieldValue.delete(),
    });

    await batch.commit();
  }

  // 6. Stream Single Ride (For Client & Driver)
  Stream<DocumentSnapshot> streamRide(String rideId) {
    return _firestore.collection('rides').doc(rideId).snapshots();
  }
}
