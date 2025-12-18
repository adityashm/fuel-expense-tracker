import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/database_service.dart';

class TripProvider with ChangeNotifier {
  List<Trip> _trips = [];
  Trip? _activeTrip;
  bool _isLoading = false;

  List<Trip> get trips => _trips;
  Trip? get activeTrip => _activeTrip;
  bool get isLoading => _isLoading;
  bool get hasActiveTrip => _activeTrip != null;

  Future<void> loadTrips() async {
    _isLoading = true;
    notifyListeners();

    try {
      final maps = await DatabaseService.instance.getAllTrips();
      _trips = maps.map((map) => Trip.fromMap(map)).toList();

      // Load active trip (first active trip found)
      if (_trips.isNotEmpty) {
        try {
          _activeTrip = _trips.firstWhere(
            (trip) => trip.isActive,
          );
        } catch (e) {
          // No active trip found, that's okay
          _activeTrip = null;
        }
      } else {
        _activeTrip = null;
      }
    } catch (e) {
      debugPrint('Error loading trips: $e');
      _trips = [];
      _activeTrip = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTripsByVehicle(int vehicleId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final maps = await DatabaseService.instance.getTripsForVehicle(vehicleId);
      _trips = maps.map((map) => Trip.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error loading trips by vehicle: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<int?> startTrip({
    required int vehicleId,
    required String deviceId,
    required String startLocation,
    double? startOdometer,
    required TripPurpose purpose,
    String? notes,
  }) async {
    try {
      // Check if there's already an active trip
      if (_activeTrip != null) {
        throw Exception('There is already an active trip');
      }

      final tripId = await DatabaseService.instance.createTrip(
        vehicleId: vehicleId,
        deviceId: deviceId,
        startLocation: startLocation,
        startOdometer: startOdometer,
        startTime: DateTime.now(),
        purpose: purpose.name,
        notes: notes,
      );

      // Reload trips to get the new one
      await loadTrips();

      return tripId;
    } catch (e) {
      debugPrint('Error starting trip: $e');
      return null;
    }
  }

  Future<bool> endTrip({
    required int tripId,
    required String endLocation,
    required double endOdometer,
    String? notes,
  }) async {
    try {
      // Calculate distance safely
      double? distance;
      final activeTrip = _activeTrip;
      final startOdometer = activeTrip?.startOdometer;
      if (startOdometer != null) {
        distance = endOdometer - startOdometer;
      }

      await DatabaseService.instance.endTrip(
        tripId: tripId,
        endLocation: endLocation,
        endOdometer: endOdometer,
        distance: distance,
        endTime: DateTime.now(),
        notes: notes,
      );

      _activeTrip = null;
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error ending trip: $e');
      return false;
    }
  }

  Future<bool> deleteTrip(int tripId) async {
    try {
      await DatabaseService.instance.deleteTrip(tripId);
      _trips.removeWhere((trip) => trip.id == tripId);
      if (_activeTrip?.id == tripId) {
        _activeTrip = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting trip: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getTripStatistics() async {
    try {
      // Calculate from loaded trips
      double totalDistance = 0;
      double businessDistance = 0;
      double personalDistance = 0;

      for (final trip in _trips) {
        if (trip.calculatedDistance != null) {
          totalDistance += trip.calculatedDistance!;
          if (trip.purpose == TripPurpose.business) {
            businessDistance += trip.calculatedDistance!;
          } else {
            personalDistance += trip.calculatedDistance!;
          }
        }
      }

      return {
        'total_trips': _trips.length,
        'total_distance': totalDistance,
        'avg_distance': _trips.isNotEmpty ? totalDistance / _trips.length : 0.0,
        'business_distance': businessDistance,
        'personal_distance': personalDistance,
      };
    } catch (e) {
      debugPrint('Error getting trip statistics: $e');
      return {
        'total_trips': 0,
        'total_distance': 0.0,
        'avg_distance': 0.0,
        'business_distance': 0.0,
        'personal_distance': 0.0,
      };
    }
  }

  Future<List<Trip>> getBusinessTrips(
    String deviceId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final maps = await DatabaseService.instance
          .getBusinessTripsForDevice(deviceId, startDate, endDate);
      return maps.map((map) => Trip.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting business trips: $e');
      return [];
    }
  }

  void clearTrips() {
    _trips = [];
    _activeTrip = null;
    notifyListeners();
  }
}
