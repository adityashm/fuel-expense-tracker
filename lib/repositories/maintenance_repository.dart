import 'package:sqflite/sqflite.dart';

import 'database_provider.dart';

/// Repository for maintenance and reminder operations
class MaintenanceRepository extends DatabaseProvider {
  MaintenanceRepository._init();
  static final MaintenanceRepository instance = MaintenanceRepository._init();

  // ==================== MAINTENANCE RECORDS ====================

  /// Get maintenance records with pagination
  Future<List<Map<String, dynamic>>> getMaintenanceRecords({
    int limit = 20,
    int offset = 0,
    int? vehicleId,
    String? deviceId,
    String? type,
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

    if (type != null) {
      whereClause += ' AND type = ?';
      whereArgs.add(type);
    }

    final maps = await db.query(
      'maintenance_records',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'service_date DESC',
      limit: limit,
      offset: offset,
    );

    return maps;
  }

  /// Get maintenance record by ID
  Future<Map<String, dynamic>?> getMaintenanceRecordById(int id) async {
    final db = await database;
    final maps = await db.query(
      'maintenance_records',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  /// Insert maintenance record
  Future<int> insertMaintenanceRecord({
    required int vehicleId,
    required String deviceId,
    required String type,
    required DateTime serviceDate,
    required double cost,
    double? odometer,
    String? workshop,
    String? notes,
    DateTime? nextDueDate,
    String? documentPath,
  }) async {
    final db = await database;

    return db.insert(
      'maintenance_records',
      {
        'vehicle_id': vehicleId,
        'device_id': deviceId,
        'type': type,
        'service_date': serviceDate.toIso8601String(),
        'cost': cost,
        'odometer': odometer,
        'workshop': workshop,
        'notes': notes,
        'next_due_date': nextDueDate?.toIso8601String(),
        'document_path': documentPath,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update maintenance record
  Future<int> updateMaintenanceRecord({
    required int id,
    String? type,
    DateTime? serviceDate,
    double? cost,
    double? odometer,
    String? workshop,
    String? notes,
    DateTime? nextDueDate,
    String? documentPath,
  }) async {
    final db = await database;

    final data = <String, dynamic>{};
    if (type != null) data['type'] = type;
    if (serviceDate != null) {
      data['service_date'] = serviceDate.toIso8601String();
    }
    if (cost != null) data['cost'] = cost;
    if (odometer != null) data['odometer'] = odometer;
    if (workshop != null) data['workshop'] = workshop;
    if (notes != null) data['notes'] = notes;
    if (nextDueDate != null) {
      data['next_due_date'] = nextDueDate.toIso8601String();
    }
    if (documentPath != null) data['document_path'] = documentPath;

    return db.update(
      'maintenance_records',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete maintenance record
  Future<int> deleteMaintenanceRecord(int id) async {
    final db = await database;
    return db.delete(
      'maintenance_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get upcoming maintenance (based on next_due_date)
  Future<List<Map<String, dynamic>>> getUpcomingMaintenance({
    int? vehicleId,
    int daysAhead = 30,
  }) async {
    final db = await database;
    final futureDate = DateTime.now().add(Duration(days: daysAhead));

    String whereClause = 'next_due_date IS NOT NULL AND next_due_date <= ?';
    final List<dynamic> whereArgs = [futureDate.toIso8601String()];

    if (vehicleId != null) {
      whereClause += ' AND vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    final maps = await db.query(
      'maintenance_records',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'next_due_date ASC',
      limit: 20,
    );

    return maps;
  }

  /// Get maintenance statistics
  Future<Map<String, dynamic>> getMaintenanceStatistics({
    int? vehicleId,
    int days = 365,
  }) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));

    String whereClause = 'service_date >= ?';
    final List<dynamic> whereArgs = [startDate.toIso8601String()];

    if (vehicleId != null) {
      whereClause += ' AND vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    final result = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as count,
        SUM(cost) as totalCost,
        AVG(cost) as avgCost,
        MIN(cost) as minCost,
        MAX(cost) as maxCost
      FROM maintenance_records
      WHERE $whereClause
    ''',
      whereArgs,
    );

    if (result.isEmpty) {
      return {
        'count': 0,
        'totalCost': 0.0,
        'avgCost': 0.0,
        'minCost': 0.0,
        'maxCost': 0.0,
      };
    }

    final row = result[0];
    return {
      'count': row['count'] ?? 0,
      'totalCost': (row['totalCost'] as num?)?.toDouble() ?? 0.0,
      'avgCost': (row['avgCost'] as num?)?.toDouble() ?? 0.0,
      'minCost': (row['minCost'] as num?)?.toDouble() ?? 0.0,
      'maxCost': (row['maxCost'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Get maintenance type distribution
  Future<Map<String, int>> getMaintenanceTypeDistribution({
    int? vehicleId,
    int days = 365,
  }) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));

    String whereClause = 'service_date >= ?';
    final List<dynamic> whereArgs = [startDate.toIso8601String()];

    if (vehicleId != null) {
      whereClause += ' AND vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    final result = await db.rawQuery(
      '''
      SELECT type, COUNT(*) as count
      FROM maintenance_records
      WHERE $whereClause
      GROUP BY type
      ORDER BY count DESC
    ''',
      whereArgs,
    );

    final distribution = <String, int>{};
    for (final row in result) {
      distribution[row['type'] as String] = row['count'] as int;
    }

    return distribution;
  }

  // ==================== REMINDERS ====================

  /// Get reminders with pagination
  Future<List<Map<String, dynamic>>> getReminders({
    int limit = 20,
    int offset = 0,
    int? vehicleId,
    String? deviceId,
    String? type,
    bool? isCompleted,
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

    if (type != null) {
      whereClause += ' AND type = ?';
      whereArgs.add(type);
    }

    if (isCompleted != null) {
      whereClause += ' AND is_completed = ?';
      whereArgs.add(isCompleted ? 1 : 0);
    }

    final maps = await db.query(
      'reminders',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'due_date ASC',
      limit: limit,
      offset: offset,
    );

    return maps;
  }

  /// Get reminder by ID
  Future<Map<String, dynamic>?> getReminderById(int id) async {
    final db = await database;
    final maps = await db.query(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  /// Insert reminder
  Future<int> insertReminder({
    required int vehicleId,
    required String deviceId,
    required String type,
    required String title,
    String? description,
    required DateTime dueDate,
  }) async {
    final db = await database;

    return db.insert(
      'reminders',
      {
        'vehicle_id': vehicleId,
        'device_id': deviceId,
        'type': type,
        'title': title,
        'description': description,
        'due_date': dueDate.toIso8601String(),
        'is_completed': 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update reminder
  Future<int> updateReminder({
    required int id,
    String? type,
    String? title,
    String? description,
    DateTime? dueDate,
  }) async {
    final db = await database;

    final data = <String, dynamic>{};
    if (type != null) data['type'] = type;
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (dueDate != null) data['due_date'] = dueDate.toIso8601String();

    return db.update(
      'reminders',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark reminder as completed
  Future<int> completeReminder(int id) async {
    final db = await database;
    return db.update(
      'reminders',
      {'is_completed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete reminder
  Future<int> deleteReminder(int id) async {
    final db = await database;
    return db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get active (incomplete) reminders
  Future<List<Map<String, dynamic>>> getActiveReminders({
    int? vehicleId,
    String? deviceId,
  }) async {
    return getReminders(
      vehicleId: vehicleId,
      deviceId: deviceId,
      isCompleted: false,
      limit: 100, // Get all active reminders
    );
  }

  /// Get overdue reminders
  Future<List<Map<String, dynamic>>> getOverdueReminders({
    int? vehicleId,
  }) async {
    final db = await database;
    final now = DateTime.now();

    String whereClause = 'is_completed = 0 AND due_date < ?';
    final List<dynamic> whereArgs = [now.toIso8601String()];

    if (vehicleId != null) {
      whereClause += ' AND vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    final maps = await db.query(
      'reminders',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'due_date ASC',
      limit: 50,
    );

    return maps;
  }

  /// Get upcoming reminders (due in next N days)
  Future<List<Map<String, dynamic>>> getUpcomingReminders({
    int? vehicleId,
    int daysAhead = 7,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: daysAhead));

    String whereClause = 'is_completed = 0 AND due_date >= ? AND due_date <= ?';
    final List<dynamic> whereArgs = [
      now.toIso8601String(),
      futureDate.toIso8601String(),
    ];

    if (vehicleId != null) {
      whereClause += ' AND vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    final maps = await db.query(
      'reminders',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'due_date ASC',
      limit: 50,
    );

    return maps;
  }

  /// Get reminder count by status
  Future<Map<String, int>> getReminderCounts({int? vehicleId}) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    if (vehicleId != null) {
      whereClause += ' AND vehicle_id = ?';
      whereArgs.add(vehicleId);
    }

    final total = await db.rawQuery(
      'SELECT COUNT(*) as count FROM reminders WHERE $whereClause',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    final completed = await db.rawQuery(
      'SELECT COUNT(*) as count FROM reminders WHERE $whereClause AND is_completed = 1',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    final active = await db.rawQuery(
      'SELECT COUNT(*) as count FROM reminders WHERE $whereClause AND is_completed = 0',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return {
      'total': Sqflite.firstIntValue(total) ?? 0,
      'completed': Sqflite.firstIntValue(completed) ?? 0,
      'active': Sqflite.firstIntValue(active) ?? 0,
    };
  }

  /// Snooze reminder (update due date)
  Future<int> snoozeReminder(int id, DateTime newDueDate) async {
    final db = await database;
    return db.update(
      'reminders',
      {'due_date': newDueDate.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
