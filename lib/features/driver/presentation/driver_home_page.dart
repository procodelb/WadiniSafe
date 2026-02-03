import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../rides/data/ride_repository.dart';
import '../../../core/services/location_service.dart';
import '../../map/services/polyline_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../chat/presentation/chat_page.dart';
import '../../ratings/presentation/rating_dialog.dart';

class DriverHomePage extends ConsumerStatefulWidget {
  const DriverHomePage({super.key});

  @override
  ConsumerState<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends ConsumerState<DriverHomePage> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _isOnline = false;
  String _driverId = 'test_driver_1';
  String? _activeRideId;
  String? _vehicleType;
  List<LatLng> _ridePolyline = [];

  // Active Ride Info

  @override
  void initState() {
    super.initState();
    // Get real ID if available
    final user = ref.read(authControllerProvider).user.value;
    if (user != null) {
      _driverId = user.uid;
    }
    _getCurrentLocation();
    _loadDriverProfile();
  }

  Future<void> _loadDriverProfile() async {
    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_driverId)
          .get();
      if (driverDoc.exists) {
        final data = driverDoc.data();
        if (data != null) {
          if (mounted) {
            setState(() {
              _vehicleType = data['vehicleType'];
            });
          }

          if (data.containsKey('activeRideId')) {
            final rideId = data['activeRideId'];
            if (rideId != null) {
              setState(() => _activeRideId = rideId);

              // Restore Polyline
              final rideDoc = await FirebaseFirestore.instance
                  .collection('rides')
                  .doc(rideId)
                  .get();
              if (rideDoc.exists && _currentLocation != null) {
                final rideData = rideDoc.data()!;
                final status = rideData['status'];
                final target = status == 'accepted'
                    ? rideData['pickup']
                    : rideData['dropoff'];
                final targetLatLng = LatLng(target['lat'], target['lng']);

                final polyline =
                    await ref.read(polylineServiceProvider).getRoutePolyline(
                          pickup: _currentLocation!,
                          dropoff: targetLatLng,
                        );
                if (mounted) setState(() => _ridePolyline = polyline);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading driver profile: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position =
          await ref.read(locationServiceProvider).getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_currentLocation!, 15.0);
    } catch (e) {
      debugPrint("Location Error: $e");
    }
  }

  void _toggleOnline(bool value) {
    setState(() => _isOnline = value);
    if (value) {
      ref.read(locationServiceProvider).startTracking(_driverId);
    } else {
      ref.read(locationServiceProvider).stopTracking();
    }
  }

  Future<void> _acceptRide(String rideId, Map<String, dynamic> rideData) async {
    try {
      await ref.read(rideRepositoryProvider).acceptRide(
            rideId: rideId,
            driverId: _driverId,
          );
      setState(() {
        _activeRideId = rideId;
      });

      // Calculate route to pickup
      final pickup = rideData['pickup'];
      final pickupLatLng = LatLng(pickup['lat'], pickup['lng']);

      if (_currentLocation != null) {
        final polyline =
            await ref.read(polylineServiceProvider).getRoutePolyline(
                  pickup: _currentLocation!,
                  dropoff: pickupLatLng,
                );
        setState(() => _ridePolyline = polyline);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting ride: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Requests Stream (Only when online and no active ride)
    final requestsStream =
        (_isOnline && _activeRideId == null && _currentLocation != null)
            ? ref.watch(rideRepositoryProvider).getNearbyRequests(
                  lat: _currentLocation!.latitude,
                  lng: _currentLocation!.longitude,
                  radiusInKm: 10.0,
                  vehicleType: _vehicleType,
                )
            : const Stream<List<DocumentSnapshot>>.empty();

    // 2. Active Ride Stream
    final activeRideStream = _activeRideId != null
        ? ref.watch(rideRepositoryProvider).streamRide(_activeRideId!)
        : const Stream<DocumentSnapshot?>.empty();

    return Scaffold(
      appBar: AppBar(
        title: const Text('WadiniSafe Driver'),
        actions: [
          // Simulation Button (Debug)
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Simulate Movement',
            onPressed: () {
              if (_isOnline) {
                // If already online, toggle simulation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Starting Simulation...')),
                );
                ref.read(locationServiceProvider).startSimulation(_driverId);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Go Online first!')),
                );
              }
            },
          ),
          Switch(
            value: _isOnline,
            onChanged: _toggleOnline,
            activeColor: AppColors.success,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? const LatLng(34.4367, 35.8497),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.wadinisafe.app',
              ),

              // Polyline
              if (_ridePolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _ridePolyline,
                      strokeWidth: 4.0,
                      color: AppColors.mapRoute,
                    ),
                  ],
                ),

              // Current Location Marker
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.directions_car,
                          color: AppColors.primary, size: 30),
                    ),
                  ],
                ),

              // Request Markers
              StreamBuilder<List<DocumentSnapshot>>(
                stream: requestsStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return MarkerLayer(
                    markers: snapshot.data!.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final pickup = data['pickup'];
                      return Marker(
                        point: LatLng(pickup['lat'], pickup['lng']),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.person_pin_circle,
                            color: AppColors.secondary, size: 40),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),

          // Requests List Overlay
          if (_isOnline && _activeRideId == null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: StreamBuilder<List<DocumentSnapshot>>(
                stream: requestsStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Waiting for requests...',
                            textAlign: TextAlign.center),
                      ),
                    );
                  }

                  // Show first request for simplicity
                  final reqDoc = snapshot.data!.first;
                  final reqData = reqDoc.data() as Map<String, dynamic>;

                  return Card(
                    color: AppColors.surfaceLight,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'New Ride Request!',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: AppColors.primary),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const Icon(Icons.my_location),
                            title: Text(reqData['pickup']['address'] ??
                                'Pickup Location'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.location_on),
                            title: Text(reqData['dropoff']['address'] ??
                                'Dropoff Location'),
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            text: 'Accept Ride',
                            onPressed: () => _acceptRide(reqDoc.id, reqData),
                            color: AppColors.success,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Active Ride Overlay
          if (_activeRideId != null)
            StreamBuilder<DocumentSnapshot>(
              stream: activeRideStream.cast<DocumentSnapshot>(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const SizedBox.shrink();
                }
                final rideData = snapshot.data!.data() as Map<String, dynamic>;
                final status = rideData['status'] as String;
                final clientId = rideData['clientId'] as String;

                return Stack(
                  children: [
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                status == 'accepted'
                                    ? 'Picking up Client'
                                    : 'Heading to Dropoff',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              if (status == 'accepted')
                                AppButton(
                                  text: 'Start Ride',
                                  onPressed: () async {
                                    await ref
                                        .read(rideRepositoryProvider)
                                        .updateRideStatus(
                                            rideId: _activeRideId!,
                                            status: 'in_progress');
                                    // Update polyline to dropoff
                                    final dropoff = rideData['dropoff'];
                                    final dropoffLatLng =
                                        LatLng(dropoff['lat'], dropoff['lng']);
                                    if (_currentLocation != null) {
                                      final polyline = await ref
                                          .read(polylineServiceProvider)
                                          .getRoutePolyline(
                                              pickup: _currentLocation!,
                                              dropoff: dropoffLatLng);
                                      setState(() => _ridePolyline = polyline);
                                    }
                                  },
                                ),
                              if (status == 'in_progress')
                                AppButton(
                                  text: 'Complete Ride',
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => RatingDialog(
                                        rideId: _activeRideId!,
                                        currentUserId: _driverId,
                                        targetUserId: clientId,
                                        targetUserRole: 'client',
                                      ),
                                    ).then((_) {
                                      ref
                                          .read(rideRepositoryProvider)
                                          .completeRide(
                                              rideId: _activeRideId!,
                                              driverId: _driverId);
                                      setState(() {
                                        _activeRideId = null;
                                        _ridePolyline = [];
                                      });
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Chat Button
                    Positioned(
                      top: 16,
                      right: 16,
                      child: FloatingActionButton(
                        mini: true,
                        heroTag: 'driver_chat',
                        child: const Icon(Icons.chat),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                rideId: _activeRideId!,
                                currentUserId: _driverId,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
