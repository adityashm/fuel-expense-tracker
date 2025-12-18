import 'package:flutter/material.dart';

import '../models/maintenance_record.dart';
import '../services/collaboration_service.dart';
import '../services/database_service.dart';
import '../services/maintenance_service.dart';

class MaintenanceProvider extends ChangeNotifier {
  final MaintenanceService _service = MaintenanceService.instance;
  final Map<int, List<MaintenanceRecord>> _recordsByVehicle = {};
  final Map<int, bool> _loadingState = {};
  final Map<int, Map<String, dynamic>> _summaryCache = {};

  List<MaintenanceRecord> recordsForVehicle(int vehicleId) =>
      _recordsByVehicle[vehicleId] ?? const <MaintenanceRecord>[];

  bool isLoading(int vehicleId) => _loadingState[vehicleId] ?? false;

  Map<String, dynamic>? summaryForVehicle(int vehicleId) =>
      _summaryCache[vehicleId];

  Future<void> loadRecords(int vehicleId) async {
    _loadingState[vehicleId] = true;
    notifyListeners();

    final records = await _service.getRecordsForVehicle(vehicleId);
    _recordsByVehicle[vehicleId] = records;
    await _refreshSummary(vehicleId);

    _loadingState[vehicleId] = false;
    notifyListeners();
  }

  Future<void> addRecord(MaintenanceRecord record) async {
    final saved = await _service.addRecord(record);
    _recordsByVehicle.putIfAbsent(record.vehicleId, () => []).insert(0, saved);
    await _refreshSummary(record.vehicleId);
    await _logMaintenanceActivity(saved);
    notifyListeners();
  }

  Future<void> updateRecord(MaintenanceRecord record) async {
    await _service.updateRecord(record);
    final list = _recordsByVehicle[record.vehicleId];
    if (list != null) {
      final index = list.indexWhere((item) => item.id == record.id);
      if (index != -1) {
        list[index] = record;
      }
    }
    await _refreshSummary(record.vehicleId);
    notifyListeners();
  }

  Future<void> deleteRecord(int vehicleId, int recordId) async {
    await _service.deleteRecord(recordId);
    final list = _recordsByVehicle[vehicleId];
    list?.removeWhere((item) => item.id == recordId);
    await _refreshSummary(vehicleId);
    notifyListeners();
  }

  Future<List<MaintenanceRecord>> getUpcomingDue(int vehicleId) async {
    return _service.getUpcomingDueRecords(vehicleId);
  }

  Future<void> _refreshSummary(int vehicleId) async {
    _summaryCache[vehicleId] = await _service.getMaintenanceSummary(vehicleId);
  }

  Future<void> _logMaintenanceActivity(MaintenanceRecord record) async {
    final vehicle = await DatabaseService.instance.getVehicle(record.vehicleId);
    await CollaborationService.instance.logActivity(
      vehicleId: record.vehicleId,
      deviceId: record.deviceId,
      title: 'Maintenance logged',
      description:
          '₹${record.cost.toStringAsFixed(0)} • ${record.type.name} ${vehicle != null ? 'on ${vehicle.name}' : ''}',
      type: 'maintenance',
      referenceType: 'maintenance',
      referenceId: record.id,
      notify: vehicle?.isShared ?? false,
    );
  }
}
