import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final mapRepositoryProvider = Provider<MapRepository>((ref) {
  return MapRepository(FirebaseFirestore.instance, GeoFlutterFire());
});

class MapRepository {
  final FirebaseFirestore _firestore;
  final GeoFlutterFire _geo;

  MapRepository(this._firestore, this._geo);

  // 1. Listen to nearby drivers
  Stream<List<DocumentSnapshot>> getNearbyDrivers({
    required double lat,
    required double lng,
    required double radiusInKm,
    String? vehicleType,
    double? minRating,
  }) {
    final center = _geo.point(latitude: lat, longitude: lng);
    Query collectionRef =
        _firestore.collection('drivers').where('isOnline', isEqualTo: true);

    if (vehicleType != null && vehicleType.isNotEmpty) {
      collectionRef =
          collectionRef.where('vehicleType', isEqualTo: vehicleType);
    }

    // Rating filtering must be done client-side because Firestore doesn't support
    // inequality on 'rating' AND range on 'geohash' in the same query.
    Stream<List<DocumentSnapshot>> stream =
        _geo.collection(collectionRef: collectionRef).within(
              center: center,
              radius: radiusInKm,
              field: 'lastLocation',
              strictMode: true,
            );

    if (minRating != null) {
      stream = stream.map((list) {
        return list.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final rating = data['rating'] as num?;
          return rating != null && rating >= minRating;
        }).toList();
      });
    }

    return stream;
  }

  // 1.5 Update Online Status
  Future<void> setDriverOnline(String driverId, bool isOnline) async {
    await _firestore.collection('drivers').doc(driverId).update({
      'isOnline': isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 2. Update Driver Location (Throttled call usually happens in Service, but this is the raw write)
  Future<void> updateDriverLocation({
    required String driverId,
    required double lat,
    required double lng,
    required double heading,
    required double speed,
  }) async {
    final geoFirePoint = _geo.point(latitude: lat, longitude: lng);

    await _firestore.collection('drivers').doc(driverId).update({
      'lastLocation': {
        'geohash': geoFirePoint.hash,
        'lat': lat,
        'lng': lng,
        'heading': heading,
        'speed': speed,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    });
  }

  // 4. Stream single driver
  Stream<DocumentSnapshot> streamDriver(String driverId) {
    return _firestore.collection('drivers').doc(driverId).snapshots();
  }

  // 3. Admin: Listen to ALL online drivers (or viewport based)
  // For 5000+ users, listening to ALL is expensive. Use viewport or pagination.
  // Here we show viewport query.
  Stream<List<DocumentSnapshot>> getDriversInViewport({
    required double centerLat,
    required double centerLng,
    required double radiusInKm,
  }) {
    // Re-use nearby logic for viewport
    return getNearbyDrivers(
        lat: centerLat, lng: centerLng, radiusInKm: radiusInKm);
  }
}
