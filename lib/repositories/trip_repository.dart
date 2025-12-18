import 'package:sqflite/sqflite.dart';

import 'database_provider.dart';

/// Repository for trip operations
class TripRepository extends DatabaseProvider {
  TripRepository._init();
  static final TripRepository instance = TripRepository._init();

  /// Get trips with pagination
  Future<List<Map<String, dynamic>>> getTrips({
    int limit = 20,
    int offset = 0,
    int? vehicleId,
    String? deviceId,
    bool? isActive,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    if (vehicleId != null) {
      whereClause += ' AND vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

    if (isActive != null) {
      whereClause += ' AND is_active = ?';
      whereArgs.add(isActive ? 1 : 0);
    }

    final maps = await db.query(
      'trips',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'start_time DESC',
      limit: limit,
      offset: offset,
    );

    return maps;
  }

  /// Get trip by ID
  Future<Map<String, dynamic>?> getTripById(int id) async {
    final db = await database;
    final maps = await db.query(
      'trips',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  /// Start a new trip
  Future<int> startTrip({
    required int vehicleId,
    required String deviceId,
    required String startLocation,
    double? startOdometer,
    required String purpose,
    String? notes,
  }) async {
    final db = await database;

    return db.insert(
      'trips',
      {
        'vehicle_id': vehicleId,
        'device_id': deviceId,
        'start_location': startLocation,
        'start_odometer': startOdometer,
        'start_time': DateTime.now().toIso8601String(),
        'purpose': purpose,
        'notes': notes,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// End a trip
  Future<int> endTrip({
    required int tripId,
    required String endLocation,
    double? endOdometer,
    int? fuelExpenseId,
  }) async {
    final db = await database;

    final trip = await getTripById(tripId);
    if (trip == null) return 0;

    double? distance;
    if (endOdometer != null && trip['start_odometer'] != null) {
      distance = endOdometer - (trip['start_odometer'] as double);
    }

    return db.update(
      'trips',
      {
        'end_location': endLocation,
        'end_odometer': endOdometer,
        'distance': distance,
        'end_time': DateTime.now().toIso8601String(),
        'fuel_expense_id': fuelExpenseId,
        'is_active': 0,
      },
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  /// Get active trip for vehicle
  Future<Map<String, dynamic>?> getActiveTrip(int vehicleId) async {
    final db = await database;
    final maps = await db.query(
      'trips',
      where: 'vehicle_id = ? AND is_active = ?',
      whereArgs: [vehicleId, 1],
      orderBy: 'start_time DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  /// Cancel/delete active trip
  Future<int> cancelTrip(int tripId) async {
    final db = await database;
    return db.delete(
      'trips',
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  /// Get trip statistics
  Future<Map<String, dynamic>> getTripStatistics({
    int? vehicleId,
    String? deviceId,
    int days = 30,
  }) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));

    String whereClause = 'start_time >= ? AND is_active = 0';
    final List<dynamic> whereArgs = [startDate.toIso8601String()];

    if (vehicleId != null) {
      whereClause += ' AND vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

    final result = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as count,
        SUM(distance) as totalDistance,
        AVG(distance) as avgDistance,
        MIN(distance) as minDistance,
        MAX(distance) as maxDistance
      FROM trips
      WHERE $whereClause AND distance IS NOT NULL
    ''',
      whereArgs,
    );

    if (result.isEmpty) {
      return {
        'count': 0,
        'totalDistance': 0.0,
        'avgDistance': 0.0,
        'minDistance': 0.0,
        'maxDistance': 0.0,
      };
    }

    final row = result[0];
    return {
      'count': row['count'] ?? 0,
      'totalDistance': (row['totalDistance'] as num?)?.toDouble() ?? 0.0,
      'avgDistance': (row['avgDistance'] as num?)?.toDouble() ?? 0.0,
      'minDistance': (row['minDistance'] as num?)?.toDouble() ?? 0.0,
      'maxDistance': (row['maxDistance'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Get trips by purpose
  Future<List<Map<String, dynamic>>> getTripsByPurpose({
    required String purpose,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    final maps = await db.query(
      'trips',
      where: 'purpose = ?',
      whereArgs: [purpose],
      orderBy: 'start_time DESC',
      limit: limit,
      offset: offset,
    );

    return maps;
  }

  /// Get purpose distribution
  Future<Map<String, int>> getPurposeDistribution({
    int? vehicleId,
    int days = 30,
  }) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));

    String whereClause = 'start_time >= ?';
    final List<dynamic> whereArgs = [startDate.toIso8601String()];

    if (vehicleId != null) {
      whereClause += ' AND vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    final result = await db.rawQuery(
      '''
      SELECT purpose, COUNT(*) as count
      FROM trips
      WHERE $whereClause
      GROUP BY purpose
      ORDER BY count DESC
    ''',
      whereArgs,
    );

    final distribution = <String, int>{};
    for (final row in result) {
      distribution[row['purpose'] as String] = row['count'] as int;
    }

    return distribution;
  }

  /// Get total distance traveled
  Future<double> getTotalDistance({
    int? vehicleId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    String whereClause = 'is_active = 0 AND distance IS NOT NULL';
    final List<dynamic> whereArgs = [];

    if (vehicleId != null) {
      whereClause += ' AND vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    if (startDate != null) {
      whereClause += ' AND start_time >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND start_time <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery(
      'SELECT SUM(distance) as total FROM trips WHERE $whereClause',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return (result[0]['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get trip count
  Future<int> getTripCount({
    int? vehicleId,
    bool? isActive,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    if (vehicleId != null) {
      whereClause += ' AND vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    if (isActive != null) {
      whereClause += ' AND is_active = ?';
      whereArgs.add(isActive ? 1 : 0);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM trips WHERE $whereClause',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Update trip notes
  Future<int> updateNotes(int tripId, String notes) async {
    final db = await database;
    return db.update(
      'trips',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  /// Link fuel expense to trip
  Future<int> linkFuelExpense(int tripId, int fuelExpenseId) async {
    final db = await database;
    return db.update(
      'trips',
      {'fuel_expense_id': fuelExpenseId},
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  /// Get trips with linked fuel expenses
  Future<List<Map<String, dynamic>>> getTripsWithFuelExpenses({
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT t.*, f.amount_paid as fuel_cost, f.liters
      FROM trips t
      LEFT JOIN fuel_expenses f ON t.fuel_expense_id = f.id
      WHERE t.is_active = 0
      ORDER BY t.start_time DESC
      LIMIT ? OFFSET ?
    ''',
      [limit, offset],
    );
  }

  /// Calculate trip cost efficiency (cost per km)
  Future<Map<String, dynamic>> getTripCostEfficiency({
    int? vehicleId,
    int days = 30,
  }) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));

    String whereClause =
        't.start_time >= ? AND t.is_active = 0 AND t.distance IS NOT NULL AND f.amount_paid IS NOT NULL';
    final List<dynamic> whereArgs = [startDate.toIso8601String()];

    if (vehicleId != null) {
      whereClause += ' AND t.vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    final result = await db.rawQuery(
      '''
      SELECT 
        SUM(t.distance) as totalDistance,
        SUM(f.amount_paid) as totalCost,
        AVG(f.amount_paid / t.distance) as avgCostPerKm
      FROM trips t
      INNER JOIN fuel_expenses f ON t.fuel_expense_id = f.id
      WHERE $whereClause
    ''',
      whereArgs,
    );

    if (result.isEmpty) {
      return {
        'totalDistance': 0.0,
        'totalCost': 0.0,
        'avgCostPerKm': 0.0,
      };
    }

    final row = result[0];
    return {
      'totalDistance': (row['totalDistance'] as num?)?.toDouble() ?? 0.0,
      'totalCost': (row['totalCost'] as num?)?.toDouble() ?? 0.0,
      'avgCostPerKm': (row['avgCostPerKm'] as num?)?.toDouble() ?? 0.0,
    };
  }
}
