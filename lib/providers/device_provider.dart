import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
import '../services/database_service.dart';

class DeviceProvider with ChangeNotifier {
  Device? _currentDevice;
  List<Device> _allDevices = [];
  bool _isLoading = false;

  Device? get currentDevice => _currentDevice;
  List<Device> get allDevices => _allDevices;
  List<Device> get devices => _allDevices; // Alias for compatibility
  bool get isLoading => _isLoading;
  bool get hasDevice => _currentDevice != null;

  // Initialize device on app start
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Try to get device ID from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final savedDeviceId = prefs.getString('device_id');

      if (savedDeviceId != null) {
        // Load device from database
        final deviceMap =
            await DatabaseService.instance.getDeviceByDeviceId(savedDeviceId);
        if (deviceMap != null) {
          _currentDevice = Device.fromMap(deviceMap);
          await DatabaseService.instance.setActiveDevice(savedDeviceId);
        }
      }

      // Load all devices
      await _loadAllDevices();

      // Auto-register a default device if none exists
      if (_currentDevice == null && _allDevices.isEmpty) {
        debugPrint('No device found, auto-registering default device...');
        final success = await registerDevice('My Device');
        if (success) {
          debugPrint('Default device registered successfully');
        }
      }
    } catch (e) {
      debugPrint('Error initializing device: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadAllDevices() async {
    try {
      final deviceMaps = await DatabaseService.instance.getAllDevices();
      _allDevices = deviceMaps.map((map) => Device.fromMap(map)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading devices: $e');
    }
  }

  Future<bool> registerDevice(
    String personName, {
    String? profilePicturePath,
  }) async {
    try {
      final deviceId = await DatabaseService.instance.registerDevice(
        personName,
        profilePicturePath: profilePicturePath,
      );

      // Save device ID to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_id', deviceId);

      // Load the new device
      final deviceMap =
          await DatabaseService.instance.getDeviceByDeviceId(deviceId);
      if (deviceMap != null) {
        _currentDevice = Device.fromMap(deviceMap);
        await _loadAllDevices();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error registering device: $e');
    }
    return false;
  }

  Future<bool> selectDevice(String deviceId) async {
    try {
      await DatabaseService.instance.setActiveDevice(deviceId);

      final deviceMap =
          await DatabaseService.instance.getDeviceByDeviceId(deviceId);
      if (deviceMap != null) {
        _currentDevice = Device.fromMap(deviceMap);

        // Save to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('device_id', deviceId);

        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error selecting device: $e');
    }
    return false;
  }

  Future<bool> updateDeviceName(String deviceId, String newName) async {
    try {
      await DatabaseService.instance.updateDevice(
        deviceId,
        {'person_name': newName},
      );

      if (_currentDevice?.deviceId == deviceId) {
        _currentDevice = _currentDevice?.copyWith(
          personName: newName,
          updatedAt: DateTime.now(),
        );
      }

      await _loadAllDevices();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating device name: $e');
      return false;
    }
  }

  Future<bool> deleteDevice(String deviceId) async {
    try {
      await DatabaseService.instance.deleteDevice(deviceId);

      if (_currentDevice?.deviceId == deviceId) {
        _currentDevice = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('device_id');
      }

      await _loadAllDevices();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting device: $e');
      return false;
    }
  }

  void clearDevice() {
    _currentDevice = null;
    notifyListeners();
  }

  String get currentPersonName => _currentDevice?.personName ?? 'Unknown';
  String? get currentDeviceId => _currentDevice?.deviceId;
}
