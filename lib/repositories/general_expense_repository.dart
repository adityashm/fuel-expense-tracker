import 'package:sqflite/sqflite.dart';

import '../models/general_expense.dart';
import 'database_provider.dart';

/// Repository for general expense operations with pagination support
class GeneralExpenseRepository extends DatabaseProvider {
  GeneralExpenseRepository._init();
  static final GeneralExpenseRepository instance =
      GeneralExpenseRepository._init();

  /// Get general expenses with pagination
  Future<List<GeneralExpense>> getExpenses({
    int limit = 20,
    int offset = 0,
    String? deviceId,
    int? vehicleId,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    bool? isHouseholdExpense,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

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

    if (category != null) {
      whereClause += ' AND category = ?';
      whereArgs.add(category);
    }

    if (isHouseholdExpense != null) {
      whereClause += ' AND is_household_expense = ?';
      whereArgs.add(isHouseholdExpense ? 1 : 0);
    }

    final maps = await db.query(
      'general_expenses',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => GeneralExpense.fromMap(map)).toList();
  }

  /// Get count of general expenses (for pagination)
  Future<int> getExpenseCount({
    String? deviceId,
    int? vehicleId,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    bool? isHouseholdExpense,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

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

    if (category != null) {
      whereClause += ' AND category = ?';
      whereArgs.add(category);
    }

    if (isHouseholdExpense != null) {
      whereClause += ' AND is_household_expense = ?';
      whereArgs.add(isHouseholdExpense ? 1 : 0);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM general_expenses WHERE $whereClause',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get general expense by ID
  Future<GeneralExpense?> getExpenseById(int id) async {
    final db = await database;
    final maps = await db.query(
      'general_expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return GeneralExpense.fromMap(maps.first);
  }

  /// Insert general expense
  Future<int> insertExpense(GeneralExpense expense) async {
    final db = await database;
    return db.insert(
      'general_expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update general expense
  Future<int> updateExpense(GeneralExpense expense) async {
    final db = await database;
    return db.update(
      'general_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  /// Delete general expense
  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete(
      'general_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get household expenses with pagination
  Future<List<GeneralExpense>> getHouseholdExpenses({
    int limit = 20,
    int offset = 0,
    String? deviceId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return getExpenses(
      limit: limit,
      offset: offset,
      deviceId: deviceId,
      startDate: startDate,
      endDate: endDate,
      isHouseholdExpense: true,
    );
  }

  /// Get non-household expenses with pagination
  Future<List<GeneralExpense>> getNonHouseholdExpenses({
    int limit = 20,
    int offset = 0,
    String? deviceId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return getExpenses(
      limit: limit,
      offset: offset,
      deviceId: deviceId,
      startDate: startDate,
      endDate: endDate,
      isHouseholdExpense: false,
    );
  }

  /// Get expenses for a specific month
  Future<List<GeneralExpense>> getExpensesForMonth({
    required int year,
    required int month,
    bool? isHouseholdExpense,
  }) async {
    final startDate = DateTime(year, month);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    return getExpenses(
      startDate: startDate,
      endDate: endDate,
      isHouseholdExpense: isHouseholdExpense,
      limit: 1000, // Get all for month
    );
  }

  /// Get total spent
  Future<double> getTotalSpent({
    String? deviceId,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    bool? isHouseholdExpense,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

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

    if (category != null) {
      whereClause += ' AND category = ?';
      whereArgs.add(category);
    }

    if (isHouseholdExpense != null) {
      whereClause += ' AND is_household_expense = ?';
      whereArgs.add(isHouseholdExpense ? 1 : 0);
    }

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM general_expenses WHERE $whereClause',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return (result[0]['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get category breakdown
  Future<Map<String, double>> getCategoryBreakdown({
    String? deviceId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isHouseholdExpense,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

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

    if (isHouseholdExpense != null) {
      whereClause += ' AND is_household_expense = ?';
      whereArgs.add(isHouseholdExpense ? 1 : 0);
    }

    final result = await db.rawQuery(
      '''
      SELECT category, SUM(amount) as total
      FROM general_expenses
      WHERE $whereClause
      GROUP BY category
      ORDER BY total DESC
    ''',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    final breakdown = <String, double>{};
    for (final row in result) {
      breakdown[row['category'] as String] = (row['total'] as num).toDouble();
    }

    return breakdown;
  }

  /// Get expense statistics
  Future<Map<String, dynamic>> getStatistics({
    String? deviceId,
    bool? isHouseholdExpense,
    int days = 30,
  }) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));

    String whereClause = 'date >= ?';
    final List<dynamic> whereArgs = [startDate.toIso8601String()];

    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

    if (isHouseholdExpense != null) {
      whereClause += ' AND is_household_expense = ?';
      whereArgs.add(isHouseholdExpense ? 1 : 0);
    }

    final result = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as count,
        SUM(amount) as totalSpent,
        AVG(amount) as avgAmount,
        MIN(amount) as minAmount,
        MAX(amount) as maxAmount
      FROM general_expenses
      WHERE $whereClause
    ''',
      whereArgs,
    );

    if (result.isEmpty) {
      return {
        'count': 0,
        'totalSpent': 0.0,
        'avgAmount': 0.0,
        'minAmount': 0.0,
        'maxAmount': 0.0,
      };
    }

    final row = result[0];
    return {
      'count': row['count'] ?? 0,
      'totalSpent': (row['totalSpent'] as num?)?.toDouble() ?? 0.0,
      'avgAmount': (row['avgAmount'] as num?)?.toDouble() ?? 0.0,
      'minAmount': (row['minAmount'] as num?)?.toDouble() ?? 0.0,
      'maxAmount': (row['maxAmount'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Search expenses
  Future<List<GeneralExpense>> searchExpenses({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    final maps = await db.query(
      'general_expenses',
      where: 'description LIKE ? OR notes LIKE ? OR category LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => GeneralExpense.fromMap(map)).toList();
  }

  /// Get unsynced expenses
  Future<List<GeneralExpense>> getUnsyncedExpenses({int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      'general_expenses',
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return maps.map((map) => GeneralExpense.fromMap(map)).toList();
  }

  /// Mark expense as synced
  Future<int> markAsSynced(int id, String firebaseId) async {
    final db = await database;
    return db.update(
      'general_expenses',
      {'is_synced': 1, 'firebase_id': firebaseId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get recurring expenses
  Future<List<GeneralExpense>> getRecurringExpenses({
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    final maps = await db.query(
      'general_expenses',
      where: 'is_recurring = ?',
      whereArgs: [1],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => GeneralExpense.fromMap(map)).toList();
  }

  /// Get expenses by payment method
  Future<List<GeneralExpense>> getExpensesByPaymentMethod({
    required String paymentMethod,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    final maps = await db.query(
      'general_expenses',
      where: 'payment_method = ?',
      whereArgs: [paymentMethod],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => GeneralExpense.fromMap(map)).toList();
  }

  /// Get payment method distribution
  Future<Map<String, int>> getPaymentMethodDistribution({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClause += ' AND date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery(
      '''
      SELECT payment_method, COUNT(*) as count
      FROM general_expenses
      WHERE $whereClause
      GROUP BY payment_method
      ORDER BY count DESC
    ''',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    final distribution = <String, int>{};
    for (final row in result) {
      distribution[row['payment_method'] as String] = row['count'] as int;
    }

    return distribution;
  }

  /// Delete all household expenses
  Future<int> deleteAllHouseholdExpenses() async {
    final db = await database;
    return db.delete(
      'general_expenses',
      where: 'is_household_expense = ?',
      whereArgs: [1],
    );
  }

  /// Get expenses by tags
  Future<List<GeneralExpense>> getExpensesByTags({
    required String tags,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    final maps = await db.query(
      'general_expenses',
      where: 'tags LIKE ?',
      whereArgs: ['%$tags%'],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => GeneralExpense.fromMap(map)).toList();
  }
}
