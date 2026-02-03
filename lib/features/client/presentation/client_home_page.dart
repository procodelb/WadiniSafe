import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loading.dart';
import '../../map/data/map_repository.dart';
import '../../map/services/polyline_service.dart';
import '../../rides/data/ride_repository.dart';
import '../../../core/services/location_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../chat/presentation/chat_page.dart';
import '../../ratings/presentation/rating_dialog.dart';

class ClientHomePage extends ConsumerStatefulWidget {
  const ClientHomePage({super.key});

  @override
  ConsumerState<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends ConsumerState<ClientHomePage> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  String? _pickupAddress;
  String? _dropoffAddress;
  List<LatLng> _routePolyline = [];
  bool _isLoading = false;
  String _rideStatus =
      'idle'; // idle, selecting, requested, accepted, in_progress
  String? _activeRideId;
  String _clientId = 'test_client_1';

  // Filters
  String? _selectedVehicleType;
  final List<String> _vehicleTypes = [
    'Taxi',
    'Bus',
    'School Bus',
    'University Bus'
  ];
  bool _filterByBestRating = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user.value;
    if (user != null) {
      _clientId = user.uid;
    }
    _getCurrentLocation();
    _checkActiveRide();
  }

  Future<void> _checkActiveRide() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('rides')
          .where('clientId', isEqualTo: _clientId)
          .where('status', whereIn: ['requested', 'accepted', 'in_progress'])
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        setState(() {
          _activeRideId = doc.id;
          _rideStatus = data['status'];

          final pickup = data['pickup'];
          final dropoff = data['dropoff'];
          _pickupLocation = LatLng(pickup['lat'], pickup['lng']);
          _dropoffLocation = LatLng(dropoff['lat'], dropoff['lng']);
          _pickupAddress = pickup['address'];
          _dropoffAddress = dropoff['address'];
        });

        // Restore polyline
        _getPolyline();
      }
    } catch (e) {
      debugPrint('Error restoring ride: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position =
          await ref.read(locationServiceProvider).getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _pickupLocation = _currentLocation; // Default pickup to current
      });
      _getAddressFromLatLng(_currentLocation!, true);
      _mapController.move(_currentLocation!, 15.0);
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() {
        _currentLocation = const LatLng(34.4367, 35.8497);
        _pickupLocation = _currentLocation;
      });
    }
  }

  Future<void> _getAddressFromLatLng(LatLng point, bool isPickup) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(point.latitude, point.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address =
            "${place.street ?? ''}, ${place.subLocality ?? place.locality ?? ''}";
        address = address.replaceAll(RegExp(r'^, |,$'), '').trim();
        if (address.isEmpty || address == ',') address = "Unknown Location";

        if (mounted) {
          setState(() {
            if (isPickup) {
              _pickupAddress = address;
            } else {
              _dropoffAddress = address;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    if (_rideStatus == 'idle' || _rideStatus == 'selecting') {
      setState(() {
        _dropoffLocation = point;
        _rideStatus = 'selecting';
      });
      _getAddressFromLatLng(point, false);
      _getPolyline();
    }
  }

  Future<void> _getPolyline() async {
    if (_pickupLocation == null || _dropoffLocation == null) return;

    try {
      final polyline = await ref.read(polylineServiceProvider).getRoutePolyline(
            pickup: _pickupLocation!,
            dropoff: _dropoffLocation!,
          );
      setState(() {
        _routePolyline = polyline;
      });
    } catch (e) {
      debugPrint('Error getting polyline: $e');
    }
  }

  void _requestRide() async {
    if (_pickupLocation == null || _dropoffLocation == null) return;

    setState(() => _isLoading = true);

    try {
      final rideId = await ref.read(rideRepositoryProvider).requestRide(
            clientId: _clientId,
            pickupLat: _pickupLocation!.latitude,
            pickupLng: _pickupLocation!.longitude,
            pickupAddress: _pickupAddress ?? 'Unknown',
            dropoffLat: _dropoffLocation!.latitude,
            dropoffLng: _dropoffLocation!.longitude,
            dropoffAddress: _dropoffAddress ?? 'Unknown',
            vehicleType: _selectedVehicleType ?? 'Taxi',
          );

      setState(() {
        _rideStatus = 'requested';
        _activeRideId = rideId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error requesting ride: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Active Ride Stream
    final rideStream = _activeRideId != null
        ? ref.watch(rideRepositoryProvider).streamRide(_activeRideId!)
        : const Stream<DocumentSnapshot?>.empty();

    return Scaffold(
      appBar: AppBar(title: const Text('WadiniSafe Client')),
      body: StreamBuilder<DocumentSnapshot?>(
        stream: rideStream,
        builder: (context, rideSnapshot) {
          // Check if ride exists and update state
          if (rideSnapshot.hasData &&
              rideSnapshot.data != null &&
              rideSnapshot.data!.exists) {
            final rideData = rideSnapshot.data!.data() as Map<String, dynamic>;
            final status = rideData['status'] as String;
            final driverId = rideData['driverId'] as String?;

            // Handle completion
            if (status == 'completed') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_rideStatus != 'completed') {
                  setState(() {
                    _rideStatus = 'idle';
                    _activeRideId = null;
                    _dropoffLocation = null;
                    _routePolyline = [];
                  });

                  if (driverId != null) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => RatingDialog(
                        rideId: rideSnapshot.data!.id,
                        currentUserId: _clientId,
                        targetUserId: driverId,
                        targetUserRole: 'driver',
                      ),
                    );
                  }
                }
              });
            } else if (status != _rideStatus && status != 'requested') {
              // Update local status to match Firestore (e.g. accepted, in_progress)
              // Avoid setState in build if possible, but status sync is needed
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_rideStatus != status) setState(() => _rideStatus = status);
              });
            }

            return Stack(
              children: [
                _buildMap(driverId, status),
                _buildRideBottomSheet(status, rideData),
                // Chat Button
                if (status == 'accepted' || status == 'in_progress')
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      heroTag: 'chat_btn',
                      child: const Icon(Icons.chat),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              rideId: _activeRideId!,
                              currentUserId: _clientId,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          }

          // No active ride (Idle / Selecting / Requested locally)
          return Stack(
            children: [
              _buildMap(null, 'idle'),
              if (_rideStatus == 'idle') _buildFilters(),
              _buildSelectionBottomSheet(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(String? driverId, String status) {
    // Stream nearby drivers if idle
    final nearbyDriversStream =
        (_currentLocation != null && _activeRideId == null)
            ? ref.watch(locationServiceProvider).getNearbyDrivers(
                  lat: _currentLocation!.latitude,
                  lng: _currentLocation!.longitude,
                  radiusInKm: 10.0,
                  vehicleType: _selectedVehicleType,
                  minRating: _filterByBestRating ? 4.5 : null,
                )
            : const Stream<List<DocumentSnapshot>>.empty();

    // Stream assigned driver if active
    final assignedDriverStream = (driverId != null)
        ? ref.watch(mapRepositoryProvider).streamDriver(driverId)
        : const Stream<DocumentSnapshot?>.empty();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation ?? const LatLng(34.4367, 35.8497),
        initialZoom: 15.0,
        onTap: _onMapTap,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.wadinisafe.app',
        ),

        // Route Polyline
        if (_routePolyline.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePolyline,
                strokeWidth: 4.0,
                color: AppColors.mapRoute,
              ),
            ],
          ),

        // Nearby Drivers (Only when idle/selecting)
        if (_activeRideId == null)
          StreamBuilder<List<DocumentSnapshot>>(
            stream: nearbyDriversStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return MarkerLayer(
                markers: snapshot.data!.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final location = data['lastLocation'];
                  final lat = location['lat'] as double;
                  final lng = location['lng'] as double;
                  final type = data['vehicleType'] ?? 'Car';
                  return Marker(
                    point: LatLng(lat, lng),
                    width: 40,
                    height: 40,
                    child: _buildDriverMarker(type),
                  );
                }).toList(),
              );
            },
          ),

        // Assigned Driver (When accepted/in_progress)
        if (driverId != null)
          StreamBuilder<DocumentSnapshot?>(
            stream: assignedDriverStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists)
                return const SizedBox.shrink();
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final location = data['lastLocation'];
              final lat = location['lat'] as double;
              final lng = location['lng'] as double;

              // TODO: Ideally update polyline here from driver to pickup/dropoff

              return MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(lat, lng),
                    width: 50,
                    height: 50,
                    child: const Icon(Icons.directions_car,
                        color: AppColors.primary, size: 40),
                  ),
                ],
              );
            },
          ),

        // Pickup Marker
        if (_pickupLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _pickupLocation!,
                width: 40,
                height: 40,
                child: const Icon(Icons.my_location,
                    color: AppColors.primary, size: 30),
              ),
            ],
          ),

        // Dropoff Marker
        if (_dropoffLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _dropoffLocation!,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on,
                    color: AppColors.secondary, size: 40),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFilters() {
    return Positioned(
      top: 10,
      left: 16,
      right: 16,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ..._vehicleTypes.map((type) {
              final isSelected = _selectedVehicleType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedVehicleType = selected ? type : null;
                    });
                  },
                  backgroundColor: Colors.white,
                  selectedColor: AppColors.primary.withOpacity(0.2),
                ),
              );
            }),
            FilterChip(
              label: const Text('Best Rating (4.5+)'),
              selected: _filterByBestRating,
              onSelected: (selected) {
                setState(() => _filterByBestRating = selected);
              },
              backgroundColor: Colors.white,
              selectedColor: Colors.amber.withOpacity(0.2),
              avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBottomSheet() {
    if (_rideStatus != 'selecting' && _rideStatus != 'requested')
      return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_rideStatus == 'selecting') ...[
              Text('Where to?', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _buildLocationRow(Icons.my_location,
                  _pickupAddress ?? 'Current Location', 'Pickup'),
              const SizedBox(height: 8),
              _buildLocationRow(Icons.location_on,
                  _dropoffAddress ?? 'Select Destination', 'Dropoff'),
              const SizedBox(height: 16),
              if (_isLoading)
                const AppLoading()
              else
                AppButton(
                  text: 'Request Ride',
                  onPressed: _dropoffLocation != null ? _requestRide : null,
                ),
            ],
            if (_rideStatus == 'requested')
              Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Finding a driver...',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _rideStatus = 'idle';
                        _activeRideId = null;
                        _dropoffLocation = null;
                        _routePolyline = [];
                      });
                    },
                    child: const Text('Cancel Request'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideBottomSheet(String status, Map<String, dynamic> rideData) {
    String title = 'Ride Status';
    String message = '';

    if (status == 'accepted') {
      title = 'Driver is on the way';
      message = 'Your driver is coming to pickup location.';
    } else if (status == 'in_progress') {
      title = 'On Trip';
      message = 'Heading to destination.';
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 16),
            if (status == 'accepted') const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverMarker(String type) {
    IconData icon;
    Color color;
    switch (type.toLowerCase()) {
      case 'bus':
      case 'school bus':
      case 'university bus':
        icon = Icons.directions_bus;
        color = Colors.orange;
        break;
      case 'taxi':
      default:
        icon = Icons.local_taxi;
        color = Colors.black;
        break;
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)
        ],
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildLocationRow(IconData icon, String text, String label) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(text,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
