import 'package:sqflite/sqflite.dart';

import '../models/budget.dart';
import 'database_provider.dart';

/// Repository for budget operations
class BudgetRepository extends DatabaseProvider {
  BudgetRepository._init();
  static final BudgetRepository instance = BudgetRepository._init();

  /// Get budgets with pagination
  Future<List<Budget>> getBudgets({
    int limit = 20,
    int offset = 0,
    String? deviceId,
    String? month,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

    if (month != null) {
      whereClause += ' AND month = ?';
      whereArgs.add(month);
    }

    final maps = await db.query(
      'budgets',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'month DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => Budget.fromMap(map)).toList();
  }

  /// Get budget for specific month
  Future<Budget?> getBudgetForMonth(String month, String deviceId) async {
    final db = await database;
    final maps = await db.query(
      'budgets',
      where: 'month = ? AND device_id = ?',
      whereArgs: [month, deviceId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  /// Insert budget
  Future<int> insertBudget(Budget budget) async {
    final db = await database;
    return db.insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update budget
  Future<int> updateBudget(Budget budget) async {
    final db = await database;
    return db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  /// Delete budget
  Future<int> deleteBudget(int id) async {
    final db = await database;
    return db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get current month budget
  Future<Budget?> getCurrentMonthBudget(String deviceId) async {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return getBudgetForMonth(month, deviceId);
  }

  /// Calculate budget vs actual spending
  Future<Map<String, dynamic>> getBudgetAnalysis({
    required String month,
    required String deviceId,
  }) async {
    final db = await database;

    // Get budget limits
    final budget = await getBudgetForMonth(month, deviceId);
    if (budget == null) {
      return {
        'hasBudget': false,
        'fuelLimit': 0.0,
        'generalLimit': 0.0,
        'householdLimit': 0.0,
        'fuelSpent': 0.0,
        'generalSpent': 0.0,
        'householdSpent': 0.0,
      };
    }

    // Parse month to get date range
    final parts = month.split('-');
    final year = int.parse(parts[0]);
    final monthNum = int.parse(parts[1]);
    final startDate = DateTime(year, monthNum);
    final endDate = DateTime(year, monthNum + 1, 0, 23, 59, 59);

    // Get actual spending
    final fuelSpent = await db.rawQuery(
      '''
      SELECT SUM(amount_paid) as total
      FROM fuel_expenses
      WHERE device_id = ? AND date >= ? AND date <= ?
    ''',
      [deviceId, startDate.toIso8601String(), endDate.toIso8601String()],
    );

    final generalSpent = await db.rawQuery(
      '''
      SELECT SUM(amount) as total
      FROM general_expenses
      WHERE device_id = ? AND date >= ? AND date <= ? AND is_household_expense = 0
    ''',
      [deviceId, startDate.toIso8601String(), endDate.toIso8601String()],
    );

    final householdSpent = await db.rawQuery(
      '''
      SELECT SUM(amount) as total
      FROM general_expenses
      WHERE device_id = ? AND date >= ? AND date <= ? AND is_household_expense = 1
    ''',
      [deviceId, startDate.toIso8601String(), endDate.toIso8601String()],
    );

    final fuelTotal = (fuelSpent[0]['total'] as num?)?.toDouble() ?? 0.0;
    final generalTotal = (generalSpent[0]['total'] as num?)?.toDouble() ?? 0.0;
    final householdTotal =
        (householdSpent[0]['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'hasBudget': true,
      'month': month,
      'fuelLimit': budget.fuelLimit,
      'generalLimit': budget.generalLimit,
      'householdLimit': budget.householdLimit,
      'fuelSpent': fuelTotal,
      'generalSpent': generalTotal,
      'householdSpent': householdTotal,
      'fuelRemaining': budget.fuelLimit - fuelTotal,
      'generalRemaining': budget.generalLimit - generalTotal,
      'householdRemaining': budget.householdLimit - householdTotal,
      'fuelPercentage':
          budget.fuelLimit > 0 ? (fuelTotal / budget.fuelLimit * 100) : 0.0,
      'generalPercentage': budget.generalLimit > 0
          ? (generalTotal / budget.generalLimit * 100)
          : 0.0,
      'householdPercentage': budget.householdLimit > 0
          ? (householdTotal / budget.householdLimit * 100)
          : 0.0,
      'totalLimit':
          budget.fuelLimit + budget.generalLimit + budget.householdLimit,
      'totalSpent': fuelTotal + generalTotal + householdTotal,
    };
  }

  /// Get budget history with pagination
  Future<List<Map<String, dynamic>>> getBudgetHistory({
    int limit = 20,
    int offset = 0,
    String? deviceId,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

    final maps = await db.query(
      'budget_history',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'month DESC',
      limit: limit,
      offset: offset,
    );

    return maps;
  }

  /// Save budget history
  Future<int> saveBudgetHistory({
    required String deviceId,
    required String month,
    required String category,
    required double budgetLimit,
    required double actualSpent,
  }) async {
    final db = await database;

    final savings = budgetLimit - actualSpent;

    return db.insert(
      'budget_history',
      {
        'device_id': deviceId,
        'month': month,
        'category': category,
        'budget_limit': budgetLimit,
        'actual_spent': actualSpent,
        'savings': savings,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get monthly comparison (current vs previous months)
  Future<Map<String, dynamic>> getMonthlyComparison({
    required String deviceId,
    int monthsToCompare = 3,
  }) async {
    await database;

    final months = <String>[];
    final now = DateTime.now();
    for (int i = 0; i < monthsToCompare; i++) {
      final date = DateTime(now.year, now.month - i);
      months.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
    }

    final comparison = <String, Map<String, double>>{};

    for (final month in months) {
      final analysis =
          await getBudgetAnalysis(month: month, deviceId: deviceId);
      comparison[month] = {
        'fuelSpent': analysis['fuelSpent'] ?? 0.0,
        'generalSpent': analysis['generalSpent'] ?? 0.0,
        'householdSpent': analysis['householdSpent'] ?? 0.0,
        'totalSpent': analysis['totalSpent'] ?? 0.0,
      };
    }

    return comparison;
  }

  /// Check if any budget is exceeded
  Future<List<String>> getExceededBudgets({
    required String month,
    required String deviceId,
  }) async {
    final analysis = await getBudgetAnalysis(month: month, deviceId: deviceId);

    if (!(analysis['hasBudget'] as bool)) return [];

    final exceeded = <String>[];

    if ((analysis['fuelSpent'] as num) > (analysis['fuelLimit'] as num)) {
      exceeded.add('fuel');
    }
    if ((analysis['generalSpent'] as num) > (analysis['generalLimit'] as num)) {
      exceeded.add('general');
    }
    if ((analysis['householdSpent'] as num) > (analysis['householdLimit'] as num)) {
      exceeded.add('household');
    }

    return exceeded;
  }

  /// Get budget trend (increasing/decreasing over time)
  Future<Map<String, dynamic>> getBudgetTrend({
    required String deviceId,
    int months = 6,
  }) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT 
        month,
        (fuel_limit + general_limit + household_limit) as total_budget
      FROM budgets
      WHERE device_id = ?
      ORDER BY month DESC
      LIMIT ?
    ''',
      [deviceId, months],
    );

    final trend = result
        .map(
          (row) => {
            'month': row['month'],
            'total': row['total_budget'],
          },
        )
        .toList();

    return {
      'trend': trend,
      'isIncreasing': trend.length >= 2 &&
          (trend[0]['total'] as double) > (trend[1]['total'] as double),
    };
  }
}
