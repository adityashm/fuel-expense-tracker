import 'package:sqflite/sqflite.dart';

import '../models/fuel_expense.dart';
import 'database_provider.dart';

/// Repository for fuel expense operations with pagination support
class FuelExpenseRepository extends DatabaseProvider {
  FuelExpenseRepository._init();
  static final FuelExpenseRepository instance = FuelExpenseRepository._init();

  /// Get fuel expenses with pagination
  Future<List<FuelExpense>> getExpenses({
    int limit = 20,
    int offset = 0,
    int? vehicleId,
    String? deviceId,
    DateTime? startDate,
    DateTime? endDate,
    String? fuelType,
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

    if (startDate != null) {
      whereClause += ' AND date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    if (fuelType != null) {
      whereClause += ' AND fuel_type = ?';
      whereArgs.add(fuelType);
    }

    final maps = await db.query(
      'fuel_expenses',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => FuelExpense.fromMap(map)).toList();
  }

  /// Get count of fuel expenses (for pagination)
  Future<int> getExpenseCount({
    int? vehicleId,
    String? deviceId,
    DateTime? startDate,
    DateTime? endDate,
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

    if (startDate != null) {
      whereClause += ' AND date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM fuel_expenses WHERE $whereClause',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get fuel expense by ID
  Future<FuelExpense?> getExpenseById(int id) async {
    final db = await database;
    final maps = await db.query(
      'fuel_expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return FuelExpense.fromMap(maps.first);
  }

  /// Insert fuel expense
  Future<int> insertExpense(FuelExpense expense) async {
    final db = await database;
    return db.insert(
      'fuel_expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update fuel expense
  Future<int> updateExpense(FuelExpense expense) async {
    final db = await database;
    return db.update(
      'fuel_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  /// Delete fuel expense
  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete(
      'fuel_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get latest fuel expense for a vehicle
  Future<FuelExpense?> getLatestExpense(int vehicleId) async {
    final db = await database;
    final maps = await db.query(
      'fuel_expenses',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC, id DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return FuelExpense.fromMap(maps.first);
  }

  /// Get fuel expenses for a specific month
  Future<List<FuelExpense>> getExpensesForMonth({
    required int year,
    required int month,
    int? vehicleId,
  }) async {
    final startDate = DateTime(year, month);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    return getExpenses(
      startDate: startDate,
      endDate: endDate,
      vehicleId: vehicleId,
      limit: 1000, // Get all for month
    );
  }

  /// Calculate average fuel efficiency
  Future<double> getAverageFuelEfficiency(int vehicleId,
      {int days = 30,}) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));

    final result = await db.rawQuery(
      '''
      SELECT 
        (MAX(odometer) - MIN(odometer)) as distance,
        SUM(liters) as totalLiters
      FROM fuel_expenses
      WHERE vehicle_id = ?
        AND date >= ?
        AND is_full_tank = 1
      ORDER BY date ASC
    ''',
      [vehicleId, startDate.toIso8601String()],
    );

    if (result.isEmpty) return 0.0;

    final distance = (result[0]['distance'] as num?)?.toDouble() ?? 0.0;
    final totalLiters = (result[0]['totalLiters'] as num?)?.toDouble() ?? 0.0;

    if (totalLiters == 0) return 0.0;
    return distance / totalLiters;
  }

  /// Get total spent on fuel
  Future<double> getTotalSpent({
    int? vehicleId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    if (vehicleId != null) {
      whereClause += ' AND vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    if (startDate != null) {
      whereClause += ' AND date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery(
      'SELECT SUM(amount_paid) as total FROM fuel_expenses WHERE $whereClause',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return (result[0]['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get fuel expenses by date range
  Future<List<FuelExpense>> getExpensesByDateRange(
    DateTime startDate,
    DateTime endDate, {
    int? vehicleId,
  }) async {
    return getExpenses(
      startDate: startDate,
      endDate: endDate,
      vehicleId: vehicleId,
      limit: 1000, // Get all in range
    );
  }

  /// Get unsynced fuel expenses
  Future<List<FuelExpense>> getUnsyncedExpenses({int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      'fuel_expenses',
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return maps.map((map) => FuelExpense.fromMap(map)).toList();
  }

  /// Mark expense as synced
  Future<int> markAsSynced(int id, String firebaseId) async {
    final db = await database;
    return db.update(
      'fuel_expenses',
      {'is_synced': 1, 'firebase_id': firebaseId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get fuel statistics for dashboard
  Future<Map<String, dynamic>> getFuelStatistics({
    int? vehicleId,
    int days = 30,
  }) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));

    String whereClause = 'date >= ?';
    final List<dynamic> whereArgs = [startDate.toIso8601String()];

    if (vehicleId != null) {
      whereClause += ' AND vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    final result = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as count,
        SUM(amount_paid) as totalSpent,
        SUM(liters) as totalLiters,
        AVG(price_per_liter) as avgPricePerLiter,
        MIN(price_per_liter) as minPrice,
        MAX(price_per_liter) as maxPrice
      FROM fuel_expenses
      WHERE $whereClause
    ''',
      whereArgs,
    );

    if (result.isEmpty) {
      return {
        'count': 0,
        'totalSpent': 0.0,
        'totalLiters': 0.0,
        'avgPricePerLiter': 0.0,
        'minPrice': 0.0,
        'maxPrice': 0.0,
      };
    }

    final row = result[0];
    return {
      'count': row['count'] ?? 0,
      'totalSpent': (row['totalSpent'] as num?)?.toDouble() ?? 0.0,
      'totalLiters': (row['totalLiters'] as num?)?.toDouble() ?? 0.0,
      'avgPricePerLiter': (row['avgPricePerLiter'] as num?)?.toDouble() ?? 0.0,
      'minPrice': (row['minPrice'] as num?)?.toDouble() ?? 0.0,
      'maxPrice': (row['maxPrice'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Search fuel expenses
  Future<List<FuelExpense>> searchExpenses({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    final maps = await db.query(
      'fuel_expenses',
      where: 'station_name LIKE ? OR location LIKE ? OR notes LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => FuelExpense.fromMap(map)).toList();
  }

  /// Delete all fuel expenses for a vehicle
  Future<int> deleteAllForVehicle(int vehicleId) async {
    final db = await database;
    return db.delete(
      'fuel_expenses',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
    );
  }

  /// Get fuel type distribution
  Future<Map<String, int>> getFuelTypeDistribution({
    int? vehicleId,
    int days = 30,
  }) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));

    String whereClause = 'date >= ?';
    final List<dynamic> whereArgs = [startDate.toIso8601String()];

    if (vehicleId != null) {
      whereClause += ' AND vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    final result = await db.rawQuery(
      '''
      SELECT fuel_type, COUNT(*) as count
      FROM fuel_expenses
      WHERE $whereClause
      GROUP BY fuel_type
      ORDER BY count DESC
    ''',
      whereArgs,
    );

    final distribution = <String, int>{};
    for (final row in result) {
      distribution[row['fuel_type'] as String] = row['count'] as int;
    }

    return distribution;
  }
}
