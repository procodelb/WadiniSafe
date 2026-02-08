import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepository(FirebaseFirestore.instance);
});

class RideRepository {
  final FirebaseFirestore _firestore;

  RideRepository(this._firestore);

  // // 1.5 Migrate Rides: Add geopoint to existing rides without it
  // Future<void> migrateRidesToIncludeGeopoint() async {
  //   try {
  //     final ridesSnapshot =
  //         await _firestore.collection('rides').where('status', isEqualTo: 'requested').get();

  //     for (final doc in ridesSnapshot.docs) {
  //       final pickup = doc['pickup'] as Map<String, dynamic>?;
  //       if (pickup != null && pickup['geopoint'] == null) {
  //         final lat = pickup['lat'] as num?;
  //         final lng = pickup['lng'] as num?;
  //         if (lat != null && lng != null) {
  //           await doc.reference.update({
  //             'pickup.geopoint': GeoPoint(lat.toDouble(), lng.toDouble()),
  //           });
  //           print('Migrated ride ${doc.id} to include geopoint');
  //         }
  //       }
  //     }
  //   } catch (e) {
  //     print('Error migrating rides: $e');
  //   }
  // }

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
        'geopoint': GeoPoint(pickupLat, pickupLng),
        'geohash': pickupPoint.hash,
        'lat': pickupLat,
        'lng': pickupLng,
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
  // Note: vehicleType filtering is done client-side to avoid composite index requirement
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

    return geo
        .collection(collectionRef: collectionRef)
        .within(
          center: center,
          radius: radiusInKm,
          field: 'pickup',
          strictMode: false,
        )
        .map((rides) {
      // Pre-filter: exclude rides without valid geohash to prevent GeoFlutterFire parsing errors
      final validRides = rides.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        final pickup = data?['pickup'] as Map<String, dynamic>?;
        final geohash = pickup?['geohash'];
        return geohash != null && geohash is String;
      }).toList();

      // Client-side filter by vehicleType if provided
      if (vehicleType != null && vehicleType.isNotEmpty) {
        return validRides.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          final rideVehicleType = data?['vehicleType'] as String?;
          return rideVehicleType == vehicleType;
        }).toList();
      }
      return validRides;
    }).handleError((error) {
      print('Error querying nearby rides: $error');
      return <DocumentSnapshot>[];
    });
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
