
import '../models/vehicle.dart';
import 'database_service_base.dart';

/// Vehicle database operations
/// 
/// Manages all database operations for vehicles including:
/// - Creating, updating, and deleting vehicle records
/// - Querying vehicles by owner, device, or registration
/// - Retrieving vehicle statistics and cost data
/// - Managing vehicle access for multi-device scenarios
class VehicleDatabase extends DatabaseServiceBase {
  /// Creates a new vehicle record
  /// 
  /// Parameters:
  ///   - vehicle: Vehicle object with vehicle details
  /// 
  /// Returns: The created Vehicle object with generated ID
  /// 
  /// Example:
  /// ```dart
  /// final vehicle = Vehicle(
  ///   name: 'My Tesla',
  ///   registrationNumber: 'ABC-123',
  ///   vehicleType: VehicleType.electricCar,
  ///   ownerDeviceId: 'device123',
  ///   currentOdometer: 45000,
  /// );
  /// final created = await db.createVehicle(vehicle);
  /// ```
  Future<Vehicle> createVehicle(Vehicle vehicle) async {
    final db = await database;
    final id = await db.insert('vehicles', vehicle.toMap());
    return Vehicle(
      id: id,
      ownerDeviceId: vehicle.ownerDeviceId,
      name: vehicle.name,
      registrationNumber: vehicle.registrationNumber,
      vehicleType: vehicle.vehicleType,
      currentOdometer: vehicle.currentOdometer,
      isShared: vehicle.isShared,
      monthlyBudget: vehicle.monthlyBudget,
    );
  }

  /// Retrieves all vehicles owned/registered by a device
  /// 
  /// Parameters:
  ///   - deviceId: Device identifier
  /// 
  /// Returns: List of Vehicle objects for the device
  /// 
  /// Retrieves only vehicles where the device is the owner
  Future<List<Vehicle>> getVehiclesByOwnerDevice(String deviceId) async {
    final db = await database;
    final result = await db.query(
      'vehicles',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'name ASC',
    );

    return result.map((map) => Vehicle.fromMap(map)).toList();
  }

  /// Retrieves all vehicles in the database
  /// 
  /// Returns: List of all Vehicle objects
  /// 
  /// Warning: In multi-device scenarios, this may return vehicles
  /// from other devices. Use [getVehiclesByOwnerDevice] for device-specific queries
  Future<List<Vehicle>> getAllVehicles() async {
    final db = await database;
    final result = await db.query('vehicles', orderBy: 'name ASC');

    return result.map((map) => Vehicle.fromMap(map)).toList();
  }

  /// Retrieves a specific vehicle by ID
  /// 
  /// Parameters:
  ///   - id: Vehicle ID
  /// 
  /// Returns: Vehicle object or null if not found
  /// 
  /// Example:
  /// ```dart
  /// final vehicle = await db.getVehicle(1);
  /// if (vehicle != null) {
  ///   print('Vehicle: ${vehicle.name}');
  /// }
  /// ```
  Future<Vehicle?> getVehicle(int id) async {
    final db = await database;
    final result = await db.query(
      'vehicles',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;
    return Vehicle.fromMap(result.first);
  }

  /// Retrieves a vehicle by registration number
  /// 
  /// Parameters:
  ///   - registrationNumber: Vehicle registration/license plate number
  /// 
  /// Returns: Vehicle object or null if not found
  /// 
  /// Useful for searching vehicles by their real-world identifier
  Future<Vehicle?> getVehicleByRegistration(String registrationNumber) async {
    final db = await database;
    final result = await db.query(
      'vehicles',
      where: 'registrationNumber = ?',
      whereArgs: [registrationNumber],
    );

    if (result.isEmpty) return null;
    return Vehicle.fromMap(result.first);
  }

  /// Updates a vehicle record
  /// 
  /// Parameters:
  ///   - vehicle: Updated Vehicle object
  ///   - deviceId: Optional device ID for ownership verification
  /// 
  /// Returns: Number of rows updated (should be 1 for success)
  /// 
  /// If deviceId is provided, only updates vehicles owned by that device
  /// (security measure for multi-device apps)
  Future<int> updateVehicle(Vehicle vehicle, String? deviceId) async {
    final db = await database;
    
    String whereClause = 'id = ?';
    final List<dynamic> whereArgs = [vehicle.id];
    
    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

    return db.update(
      'vehicles',
      vehicle.toMap(),
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  /// Deletes a vehicle record
  /// 
  /// Parameters:
  ///   - id: ID of the vehicle to delete
  ///   - deviceId: Optional device ID for ownership verification
  /// 
  /// Returns: Number of rows deleted (should be 1 for success)
  /// 
  /// Warning: This will cascade delete all expenses associated with the vehicle
  /// based on foreign key constraints
  Future<int> deleteVehicle(int id, String? deviceId) async {
    final db = await database;
    
    String whereClause = 'id = ?';
    final List<dynamic> whereArgs = [id];
    
    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

    return db.delete(
      'vehicles',
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  /// Gets cost statistics for a vehicle
  /// 
  /// Parameters:
  ///   - vehicleId: ID of the vehicle
  /// 
  /// Returns: Map containing cost statistics or null if vehicle not found:
  ///   - 'totalFuelExpenses': Sum of all fuel expenses
  ///   - 'totalGeneralExpenses': Sum of general/maintenance expenses
  ///   - 'fuelExpenseCount': Number of fuel expense records
  ///   - 'generalExpenseCount': Number of general expense records
  ///   - 'totalExpenses': Combined total of all expenses
  ///   - 'avgFuelExpense': Average cost per fuel transaction
  ///   - 'avgGeneralExpense': Average cost per general transaction
  /// 
  /// Useful for vehicle cost analysis and reporting
  Future<Map<String, double>?> getVehicleCostStats(int vehicleId) async {
    final db = await database;
    
    // Verify vehicle exists
    final vehicle = await getVehicle(vehicleId);
    if (vehicle == null) return null;

    final fuelResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as count,
        SUM(amount) as total,
        AVG(amount) as avg
      FROM fuel_expenses
      WHERE vehicle_id = ?
    ''', [vehicleId],);

    final generalResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as count,
        SUM(amount) as total,
        AVG(amount) as avg
      FROM general_expenses
      WHERE vehicle_id = ? OR vehicle_id IS NULL
    ''', [vehicleId],);

    final fuelTotal = (fuelResult[0]['total'] as num?)?.toDouble() ?? 0.0;
    final generalTotal = (generalResult[0]['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'totalFuelExpenses': fuelTotal,
      'totalGeneralExpenses': generalTotal,
      'totalExpenses': fuelTotal + generalTotal,
      'fuelExpenseCount': (fuelResult[0]['count'] as int).toDouble(),
      'generalExpenseCount': (generalResult[0]['count'] as int).toDouble(),
      'avgFuelExpense': (fuelResult[0]['avg'] as num?)?.toDouble() ?? 0.0,
      'avgGeneralExpense': (generalResult[0]['avg'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Revokes device access to a vehicle
  /// 
  /// Parameters:
  ///   - vehicleId: ID of the vehicle
  ///   - deviceId: Device ID to revoke access for
  /// 
  /// Returns: Number of access records deleted
  /// 
  /// Removes the vehicle_access record that grants this device
  /// access to the vehicle in multi-device scenarios
  Future<int> revokeVehicleAccess(int vehicleId, String deviceId) async {
    final db = await database;
    
    return db.delete(
      'vehicle_access',
      where: 'vehicle_id = ? AND device_id = ?',
      whereArgs: [vehicleId, deviceId],
    );
  }

  /// Gets all devices with access to a specific vehicle
  /// 
  /// Parameters:
  ///   - vehicleId: ID of the vehicle
  /// 
  /// Returns: List of device IDs with access to the vehicle
  /// 
  /// Useful for understanding vehicle sharing in multi-device scenarios
  Future<List<String>> getDevicesWithAccessToVehicle(int vehicleId) async {
    final db = await database;
    final result = await db.query(
      'vehicle_access',
      columns: ['device_id'],
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      distinct: true,
    );

    return result.map((row) => row['device_id'] as String).toList();
  }

  /// Gets all vehicles accessible by a device
  /// 
  /// Parameters:
  ///   - deviceId: Device identifier
  /// 
  /// Returns: List of vehicle IDs accessible to the device
  /// 
  /// Includes both owned vehicles and vehicles shared with the device
  Future<List<int>> getAccessibleVehiclesForDevice(String deviceId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT DISTINCT v.id FROM vehicles v
      LEFT JOIN vehicle_access va ON v.id = va.vehicle_id
      WHERE v.device_id = ? OR va.device_id = ?
      ORDER BY v.name ASC
    ''', [deviceId, deviceId],);

    return result.map((row) => row['id'] as int).toList();
  }

  /// Sets a vehicle budget
  /// 
  /// Parameters:
  ///   - vehicleId: ID of the vehicle
  ///   - budget: Monthly budget amount or null to remove budget
  /// 
  /// Updates the monthlyBudget field for the vehicle
  Future<void> setVehicleBudget(int vehicleId, double? budget) async {
    final db = await database;
    
    await db.update(
      'vehicles',
      {'monthlyBudget': budget},
      where: 'id = ?',
      whereArgs: [vehicleId],
    );
  }

  /// Gets vehicle budget
  /// 
  /// Parameters:
  ///   - vehicleId: ID of the vehicle
  /// 
  /// Returns: Monthly budget amount or null if not set
  Future<double?> getVehicleBudget(int vehicleId) async {
    final db = await database;
    final result = await db.query(
      'vehicles',
      columns: ['monthlyBudget'],
      where: 'id = ?',
      whereArgs: [vehicleId],
    );

    if (result.isEmpty) return null;
    return (result[0]['monthlyBudget'] as num?)?.toDouble();
  }
}
