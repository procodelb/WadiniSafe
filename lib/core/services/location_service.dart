import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rxdart/rxdart.dart';
import '../../features/map/data/map_repository.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(ref.read(mapRepositoryProvider));
});

class LocationService {
  final MapRepository _mapRepository;
  StreamSubscription? _positionSubscription;
  String? _trackingDriverId;

  LocationService(this._mapRepository);

  Future<bool> requestPermission() async {
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      return result == LocationPermission.always ||
          result == LocationPermission.whileInUse;
    }
    return status == LocationPermission.always ||
        status == LocationPermission.whileInUse;
  }

  Future<Position> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Location permission not granted');
    }
    return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  /// Starts tracking the driver's location and updates Firestore
  /// with throttling to reduce writes.
  ///
  /// Throttling logic:
  /// - Update max every 5 seconds
  /// - OR if distance > 20 meters (handled by Geolocator settings to some extent,
  ///   but we enforce 5s throttle for DB writes)
  Future<void> startTracking(String driverId) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    // Stop existing if any
    await stopTracking();

    _trackingDriverId = driverId;
    await _mapRepository.setDriverOnline(driverId, true);

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update only if moved 10 meters
    );

    final stream =
        Geolocator.getPositionStream(locationSettings: locationSettings);

    // Throttle Firestore writes to once every 5 seconds
    _positionSubscription =
        stream.throttleTime(const Duration(seconds: 5)).listen((position) {
      _updateLocation(driverId, position);
    });
  }

  /// Simulation Mode: Moves the driver along a circular path
  Future<void> startSimulation(String driverId) async {
    // Stop real tracking
    await stopTracking();

    _trackingDriverId = driverId;
    await _mapRepository.setDriverOnline(driverId, true);

    // Tripoli Center
    double lat = 34.4367;
    double lng = 35.8497;
    double radius = 0.005; // approx 500m
    double angle = 0;

    // Emit position every 3 seconds
    _positionSubscription = Stream.periodic(const Duration(seconds: 3), (i) {
      angle += 0.1;
      return Position(
        latitude: lat + radius * cos(angle),
        longitude: lng + radius * sin(angle),
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        heading: (angle * 180 / 3.14159) % 360,
        speed: 30 / 3.6, // 30 km/h
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1,
      );
    }).listen((position) {
      _updateLocation(driverId, position);
    });
  }

  void _updateLocation(String driverId, Position position) {
    _mapRepository.updateDriverLocation(
      driverId: driverId,
      lat: position.latitude,
      lng: position.longitude,
      heading: position.heading,
      speed: position.speed,
    );
  }

  Future<void> stopTracking() async {
    _positionSubscription?.cancel();
    _positionSubscription = null;

    if (_trackingDriverId != null) {
      await _mapRepository.setDriverOnline(_trackingDriverId!, false);
      _trackingDriverId = null;
    }
  }

  Stream<Position> getPositionStream() async* {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Location permission not granted');
    }
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Stream<List<DocumentSnapshot>> getNearbyDrivers({
    required double lat,
    required double lng,
    required double radiusInKm,
    String? vehicleType,
    double? minRating,
  }) {
    return _mapRepository.getNearbyDrivers(
      lat: lat,
      lng: lng,
      radiusInKm: radiusInKm,
      vehicleType: vehicleType,
      minRating: minRating,
    );
  }
}
