import 'package:sqflite/sqflite.dart';

import '../models/vehicle.dart';
import 'database_provider.dart';

/// Repository for vehicle operations
class VehicleRepository extends DatabaseProvider {
  VehicleRepository._init();
  static final VehicleRepository instance = VehicleRepository._init();

  /// Get all vehicles with pagination
  Future<List<Vehicle>> getVehicles({
    int limit = 50,
    int offset = 0,
    String? ownerDeviceId,
    bool? isShared,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    if (ownerDeviceId != null) {
      whereClause += ' AND owner_device_id = ?';
      whereArgs.add(ownerDeviceId);
    }

    if (isShared != null) {
      whereClause += ' AND is_shared = ?';
      whereArgs.add(isShared ? 1 : 0);
    }

    final maps = await db.query(
      'vehicles',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  /// Get vehicle by ID
  Future<Vehicle?> getVehicleById(int id) async {
    final db = await database;
    final maps = await db.query(
      'vehicles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Vehicle.fromMap(maps.first);
  }

  /// Insert vehicle
  Future<int> insertVehicle(Vehicle vehicle) async {
    final db = await database;
    return db.insert(
      'vehicles',
      vehicle.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update vehicle
  Future<int> updateVehicle(Vehicle vehicle) async {
    final db = await database;
    return db.update(
      'vehicles',
      vehicle.toMap(),
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  /// Delete vehicle
  Future<int> deleteVehicle(int id) async {
    final db = await database;
    return db.delete(
      'vehicles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update odometer reading
  Future<int> updateOdometer(int vehicleId, double newOdometer) async {
    final db = await database;
    return db.update(
      'vehicles',
      {'current_odometer': newOdometer},
      where: 'id = ?',
      whereArgs: [vehicleId],
    );
  }

  /// Get shared vehicles for a device
  Future<List<Vehicle>> getSharedVehicles(String deviceId) async {
    final db = await database;

    // Get vehicles where device has access
    final result = await db.rawQuery(
      '''
      SELECT v.* FROM vehicles v
      INNER JOIN vehicle_access va ON v.id = va.vehicle_id
      WHERE va.device_id = ? AND v.is_shared = 1
      ORDER BY v.created_at DESC
    ''',
      [deviceId],
    );

    return result.map((map) => Vehicle.fromMap(map)).toList();
  }

  /// Get vehicle count
  Future<int> getVehicleCount({String? ownerDeviceId}) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    if (ownerDeviceId != null) {
      whereClause += ' AND owner_device_id = ?';
      whereArgs.add(ownerDeviceId);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM vehicles WHERE $whereClause',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Search vehicles
  Future<List<Vehicle>> searchVehicles({
    required String query,
    int limit = 20,
  }) async {
    final db = await database;
    final maps = await db.query(
      'vehicles',
      where: 'name LIKE ? OR registration_number LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  /// Get vehicle by registration number
  Future<Vehicle?> getVehicleByRegistration(String registrationNumber) async {
    final db = await database;
    final maps = await db.query(
      'vehicles',
      where: 'registration_number = ?',
      whereArgs: [registrationNumber],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Vehicle.fromMap(maps.first);
  }

  /// Get vehicles by type
  Future<List<Vehicle>> getVehiclesByType({
    required String vehicleType,
    int limit = 20,
  }) async {
    final db = await database;
    final maps = await db.query(
      'vehicles',
      where: 'vehicle_type = ?',
      whereArgs: [vehicleType],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  /// Update monthly budget
  Future<int> updateMonthlyBudget(int vehicleId, double? budget) async {
    final db = await database;
    return db.update(
      'vehicles',
      {'monthly_budget': budget},
      where: 'id = ?',
      whereArgs: [vehicleId],
    );
  }

  /// Toggle shared status
  Future<int> toggleSharedStatus(int vehicleId, bool isShared) async {
    final db = await database;
    return db.update(
      'vehicles',
      {'is_shared': isShared ? 1 : 0},
      where: 'id = ?',
      whereArgs: [vehicleId],
    );
  }

  /// Grant vehicle access to device
  Future<int> grantAccess({
    required int vehicleId,
    required String deviceId,
    required String accessType,
  }) async {
    final db = await database;
    return db.insert(
      'vehicle_access',
      {
        'vehicle_id': vehicleId,
        'device_id': deviceId,
        'access_type': accessType,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Revoke vehicle access from device
  Future<int> revokeAccess({
    required int vehicleId,
    required String deviceId,
  }) async {
    final db = await database;
    return db.delete(
      'vehicle_access',
      where: 'vehicle_id = ? AND device_id = ?',
      whereArgs: [vehicleId, deviceId],
    );
  }

  /// Get all devices with access to a vehicle
  Future<List<Map<String, dynamic>>> getVehicleAccessList(int vehicleId) async {
    final db = await database;
    return db.query(
      'vehicle_access',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'created_at DESC',
    );
  }

  /// Check if device has access to vehicle
  Future<bool> hasAccess({
    required int vehicleId,
    required String deviceId,
  }) async {
    final db = await database;

    // Check if owner
    final vehicle = await getVehicleById(vehicleId);
    if (vehicle?.ownerDeviceId == deviceId) return true;

    // Check vehicle_access table
    final result = await db.query(
      'vehicle_access',
      where: 'vehicle_id = ? AND device_id = ?',
      whereArgs: [vehicleId, deviceId],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  /// Get vehicle statistics
  Future<Map<String, dynamic>> getVehicleStatistics(int vehicleId) async {
    final db = await database;

    // Get fuel expense statistics
    final fuelStats = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as fuelExpenseCount,
        SUM(amount_paid) as totalFuelSpent,
        AVG(price_per_liter) as avgFuelPrice
      FROM fuel_expenses
      WHERE vehicle_id = ?
    ''',
      [vehicleId],
    );

    // Get general expense statistics
    final generalStats = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as generalExpenseCount,
        SUM(amount) as totalGeneralSpent
      FROM general_expenses
      WHERE vehicle_id = ?
    ''',
      [vehicleId],
    );

    // Get maintenance count
    final maintenanceStats = await db.rawQuery(
      '''
      SELECT COUNT(*) as maintenanceCount
      FROM maintenance_records
      WHERE vehicle_id = ?
    ''',
      [vehicleId],
    );

    return {
      'fuelExpenseCount': fuelStats[0]['fuelExpenseCount'] ?? 0,
      'totalFuelSpent':
          (fuelStats[0]['totalFuelSpent'] as num?)?.toDouble() ?? 0.0,
      'avgFuelPrice': (fuelStats[0]['avgFuelPrice'] as num?)?.toDouble() ?? 0.0,
      'generalExpenseCount': generalStats[0]['generalExpenseCount'] ?? 0,
      'totalGeneralSpent':
          (generalStats[0]['totalGeneralSpent'] as num?)?.toDouble() ?? 0.0,
      'maintenanceCount': maintenanceStats[0]['maintenanceCount'] ?? 0,
    };
  }
}
