import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';

class VehicleProvider extends ChangeNotifier {
  List<Vehicle> _vehicles = [];
  Vehicle? _currentVehicle;
  bool _isLoading = false;

  List<Vehicle> get vehicles => _vehicles;
  Vehicle? get currentVehicle => _currentVehicle;
  bool get isLoading => _isLoading;

  Future<void> loadVehicles(String deviceId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _vehicles =
          await DatabaseService.instance.getVehiclesByOwnerDevice(deviceId);
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
      _vehicles = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createVehicle(
    String ownerDeviceId,
    String name,
    String registrationNumber,
    VehicleType vehicleType,
    double currentOdometer, {
    bool isShared = false,
  }) async {
    try {
      final vehicle = Vehicle(
        ownerDeviceId: ownerDeviceId,
        name: name,
        registrationNumber: registrationNumber,
        vehicleType: vehicleType,
        currentOdometer: currentOdometer,
        isShared: isShared,
      );

      final createdVehicle =
          await DatabaseService.instance.createVehicle(vehicle);
      _vehicles.add(createdVehicle);
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating vehicle: $e');
      rethrow;
    }
  }

  Future<void> updateVehicle(Vehicle vehicle, String? deviceId) async {
    await DatabaseService.instance.updateVehicle(vehicle, deviceId);
    final index = _vehicles.indexWhere((v) => v.id == vehicle.id);
    if (index != -1) {
      _vehicles[index] = vehicle;
      if (_currentVehicle?.id == vehicle.id) {
        _currentVehicle = vehicle;
      }
      notifyListeners();
    }
  }

  Future<void> deleteVehicle(int vehicleId, String? deviceId) async {
    await DatabaseService.instance.deleteVehicle(vehicleId, deviceId);
    _vehicles.removeWhere((v) => v.id == vehicleId);
    if (_currentVehicle?.id == vehicleId) {
      _currentVehicle = null;
    }
    notifyListeners();
  }

  void setCurrentVehicle(Vehicle vehicle) {
    _currentVehicle = vehicle;
    notifyListeners();
  }

  void clearCurrentVehicle() {
    _currentVehicle = null;
    notifyListeners();
  }

  Future<double> calculateFuelAverage(int vehicleId) async {
    return DatabaseService.instance.calculateFuelAverage(vehicleId);
  }
}
