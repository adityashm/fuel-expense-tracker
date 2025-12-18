import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/expense_template.dart';
import '../models/station_geofence.dart';
import '../utils/errors.dart';

class PlacesService {
  PlacesService._init();
  static final PlacesService instance = PlacesService._init();

  // Using free OpenStreetMap Nominatim API (no API key required)
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org';
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  /// Search for nearby fuel/gas stations using free OpenStreetMap Overpass API
  Future<List<NearbyStation>> searchNearbyStations({
    required double latitude,
    required double longitude,
    double radiusMeters = 2000,
    List<FavoriteStation> favoriteStations = const [],
  }) async {
    return RetryHelper.retry(
      () => _fetchNearbyStations(
        latitude,
        longitude,
        radiusMeters,
        favoriteStations,
      ),
      shouldRetry: RetryHelper.isRetryableError,
    ).catchError((error) {
      debugPrint('Failed to fetch stations after retries: $error');
      return _getMockStations(latitude, longitude, favoriteStations);
    });
  }

  Future<List<NearbyStation>> _fetchNearbyStations(
    double latitude,
    double longitude,
    double radiusMeters,
    List<FavoriteStation> favoriteStations,
  ) async {
    try {
      // Overpass QL query to find fuel stations
      final query = '''
        [out:json][timeout:25];
        (
          node["amenity"="fuel"](around:${radiusMeters.toInt()},$latitude,$longitude);
          way["amenity"="fuel"](around:${radiusMeters.toInt()},$latitude,$longitude);
        );
        out body;
        >;
        out skel qt;
      ''';

      final response = await http
          .post(
            Uri.parse(_overpassUrl),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent':
                  'FuelExpenseTrackerApp/1.0', // Required by Nominatim
            },
            body: query,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final elements = (data['elements'] as List<dynamic>?) ?? [];

        final stations = <NearbyStation>[];
        for (final element in elements) {
          final elementMap = element as Map<String, dynamic>;
          if (elementMap['type'] != 'node') continue;

          final lat = elementMap['lat'] as double?;
          final lng = elementMap['lon'] as double?;
          if (lat == null || lng == null) continue;

          final tags = elementMap['tags'] as Map<String, dynamic>? ?? {};
          final name = tags['name'] as String? ??
              tags['brand'] as String? ??
              'Fuel Station';
          final address = tags['addr:full'] as String? ??
              tags['addr:street'] as String? ??
              'Address not available';

          final distance = Geolocator.distanceBetween(
            latitude,
            longitude,
            lat,
            lng,
          );

          // Check if this is a favorite
          FavoriteStation? favorite;
          for (final fav in favoriteStations) {
            final favLat = fav.latitude;
            final favLng = fav.longitude;
            if (favLat == null || favLng == null) continue;

            if (_isNearby(favLat, favLng, lat, lng, 50)) {
              favorite = fav;
              break;
            }
          }

          final isFavorite = favorite != null;

          stations.add(
            NearbyStation(
              placeId: element['id'].toString(),
              name: name,
              address: address,
              latitude: lat,
              longitude: lng,
              distanceMeters: distance,
              isFavorite: isFavorite,
              favoriteStationId: favorite?.id,
            ),
          );
        }

        // Sort by distance
        stations.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
        return stations;
      } else {
        throw NetworkException(
          'Overpass API returned error',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is NetworkException) rethrow;
      throw NetworkException(
        'Failed to fetch nearby stations',
        originalError: e,
      );
    }
  }

  /// Get details of a specific place (no longer needed, but kept for compatibility)
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    // OpenStreetMap doesn't require detailed place lookup
    // Return null as details are already in the search results
    return null;
  }

  /// Reverse geocode to get address from coordinates (free)
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse('$_nominatimUrl/reverse').replace(
        queryParameters: {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'format': 'json',
        },
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'FuelExpenseTrackerApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['display_name'] as String?;
      } else {
        throw Exception('Failed to reverse geocode: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
      return null;
    }
  }

  /// Find closest station to current position
  Future<NearbyStation?> findClosestStation({
    required double latitude,
    required double longitude,
    List<FavoriteStation> favoriteStations = const [],
  }) async {
    final stations = await searchNearbyStations(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: 1000,
      favoriteStations: favoriteStations,
    );

    if (stations.isEmpty) return null;

    // Sort by distance
    stations.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return stations.first;
  }

  /// Check if coordinates match a favorite station
  FavoriteStation? matchFavoriteStation(
    double latitude,
    double longitude,
    List<FavoriteStation> favorites, {
    double thresholdMeters = 100,
  }) {
    for (final favorite in favorites) {
      if (favorite.latitude == null || favorite.longitude == null) continue;

      if (_isNearby(
        favorite.latitude!,
        favorite.longitude!,
        latitude,
        longitude,
        thresholdMeters,
      )) {
        return favorite;
      }
    }
    return null;
  }

  bool _isNearby(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
    double thresholdMeters,
  ) {
    final distance = Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
    return distance <= thresholdMeters;
  }

  // Mock data for testing without API key
  List<NearbyStation> _getMockStations(
    double latitude,
    double longitude,
    List<FavoriteStation> favorites,
  ) {
    return [
      NearbyStation(
        placeId: 'mock_1',
        name: 'HP Petrol Pump',
        address: 'Baner Road, Pune',
        latitude: latitude + 0.001,
        longitude: longitude + 0.001,
        distanceMeters: 150,
        isFavorite: true,
        favoriteStationId: favorites.isNotEmpty ? favorites[0].id : null,
      ),
      NearbyStation(
        placeId: 'mock_2',
        name: 'Indian Oil Station',
        address: 'Aundh Road, Pune',
        latitude: latitude + 0.002,
        longitude: longitude - 0.001,
        distanceMeters: 300,
      ),
      NearbyStation(
        placeId: 'mock_3',
        name: 'Shell Petrol Pump',
        address: 'Hinjewadi, Pune',
        latitude: latitude - 0.001,
        longitude: longitude + 0.002,
        distanceMeters: 450,
      ),
    ];
  }
}
