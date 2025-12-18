import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/fuel_expense.dart';
import '../models/general_expense.dart';
import '../models/vehicle.dart';
import 'database_service.dart';

class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();
  final DatabaseService _db = DatabaseService.instance;

  Future<String> buildJsonSnapshot() async {
    final vehicles = await _db.getAllVehicles();
    final fuelExpenses = await _db.getAllFuelExpenses();
    final generalExpenses = await _db.getAllGeneralExpenses();

    // Offload heavy JSON building to a background isolate
    final jsonString = await compute<_SnapshotInput, String>(
      _buildSnapshotJsonIsolate,
      _SnapshotInput(
        vehicles: vehicles,
        fuelExpenses: fuelExpenses,
        generalExpenses: generalExpenses,
      ),
    );

    return jsonString;
  }
}

// Top-level data holder for passing into compute()
class _SnapshotInput {
  const _SnapshotInput({
    required this.vehicles,
    required this.fuelExpenses,
    required this.generalExpenses,
  });
  final List<Vehicle> vehicles;
  final List<FuelExpense> fuelExpenses;
  final List<GeneralExpense> generalExpenses;
}

// Top-level isolate function to build JSON string
String _buildSnapshotJsonIsolate(_SnapshotInput input) {
  final payload = {
    'generated_at': DateTime.now().toIso8601String(),
    'vehicle_count': input.vehicles.length,
    'fuel_expense_count': input.fuelExpenses.length,
    'general_expense_count': input.generalExpenses.length,
    'vehicles': input.vehicles
        .map(
          (v) => {
            'id': v.id,
            'owner_device_id': v.ownerDeviceId,
            'name': v.name,
            'registration_number': v.registrationNumber,
            'type': v.vehicleType.name,
            'current_odometer': v.currentOdometer,
            'is_shared': v.isShared,
            'created_at': v.createdAt.toIso8601String(),
          },
        )
        .toList(),
    'fuel_expenses': input.fuelExpenses
        .map(
          (e) => {
            'id': e.id,
            'device_id': e.deviceId,
            'vehicle_id': e.vehicleId,
            'date': e.date.toIso8601String(),
            'fuel_type': e.fuelType.name,
            'amount_paid': e.amountPaid,
            'liters': e.liters,
            'odometer_reading': e.odometerReading,
            'pump_name': e.pumpName,
            'notes': e.notes,
          },
        )
        .toList(),
    'general_expenses': input.generalExpenses
        .map(
          (e) => {
            'id': e.id,
            'device_id': e.deviceId,
            'vehicle_id': e.vehicleId,
            'date': e.date.toIso8601String(),
            'amount': e.amount,
            'category': e.category.name,
            'description': e.description,
            'is_household': e.isHouseholdExpense,
          },
        )
        .toList(),
  };

  return const JsonEncoder.withIndent('  ').convert(payload);
}
