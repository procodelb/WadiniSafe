import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_riverpod/flutter_riverpod.dart';

final polylineServiceProvider =
    Provider<PolylineService>((ref) => PolylineService());

class PolylineService {
  final String _baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  Future<List<LatLng>> getRoutePolyline({
    required LatLng pickup,
    required LatLng dropoff,
  }) async {
    final url = Uri.parse(
        '$_baseUrl/${pickup.longitude},${pickup.latitude};${dropoff.longitude},${dropoff.latitude}?overview=full&geometries=geojson');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] == null || (data['routes'] as List).isEmpty) {
          return [];
        }

        final geometry = data['routes'][0]['geometry'];
        final coordinates = geometry['coordinates'] as List;

        return coordinates.map((coord) {
          // OSRM returns [lng, lat]
          return LatLng(coord[1].toDouble(), coord[0].toDouble());
        }).toList();
      } else {
        throw Exception('Failed to load route: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching polyline: $e');
    }
  }
}
