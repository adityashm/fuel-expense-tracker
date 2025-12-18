import '../models/maintenance_record.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class MaintenanceService {
  MaintenanceService._();

  static final MaintenanceService instance = MaintenanceService._();

  DatabaseService get _dbService => DatabaseService.instance;

  Future<MaintenanceRecord> addRecord(MaintenanceRecord record) async {
    final db = await _dbService.database;
    final id = await db.insert('maintenance_records', record.toMap());
    final saved = record.copyWith(id: id);
    await _scheduleReminderIfNeeded(saved);
    return saved;
  }

  Future<int> updateRecord(MaintenanceRecord record) async {
    final db = await _dbService.database;
    final result = await db.update(
      'maintenance_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    await _scheduleReminderIfNeeded(record);
    return result;
  }

  Future<int> deleteRecord(int id) async {
    final db = await _dbService.database;
    return db.delete('maintenance_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MaintenanceRecord>> getRecordsForVehicle(int vehicleId) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'maintenance_records',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'service_date DESC',
    );
    return rows.map(MaintenanceRecord.fromMap).toList();
  }

  Future<List<MaintenanceRecord>> getUpcomingDueRecords(int vehicleId) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'maintenance_records',
      where:
          'vehicle_id = ? AND next_due_date IS NOT NULL AND next_due_date >= ?',
      whereArgs: [vehicleId, DateTime.now().toIso8601String()],
      orderBy: 'next_due_date ASC',
      limit: 5,
    );
    return rows.map(MaintenanceRecord.fromMap).toList();
  }

  Future<Map<String, dynamic>> getMaintenanceSummary(int vehicleId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) AS total_records,
        SUM(cost) AS total_cost,
        MAX(service_date) AS last_service,
        MIN(CASE WHEN next_due_date IS NOT NULL AND next_due_date >= datetime('now') THEN next_due_date END) AS next_service
      FROM maintenance_records
      WHERE vehicle_id = ?
    ''',
      [vehicleId],
    );

    final row = result.isNotEmpty ? result.first : {};
    return {
      'total_records': (row['total_records'] as int?) ?? 0,
      'total_cost': (row['total_cost'] as num?)?.toDouble() ?? 0.0,
      'last_service': row['last_service'] != null
          ? DateTime.parse(row['last_service'] as String)
          : null,
      'next_service': row['next_service'] != null
          ? DateTime.parse(row['next_service'] as String)
          : null,
    };
  }

  Future<void> _scheduleReminderIfNeeded(MaintenanceRecord record) async {
    if (record.nextDueDate == null) return;
    final vehicle = await _dbService.getVehicle(record.vehicleId);
    if (vehicle == null) return;
    final reminderId = record.id ?? DateTime.now().millisecondsSinceEpoch;
    await NotificationService.instance.scheduleServiceReminder(
      reminderId: reminderId,
      vehicleName: vehicle.name,
      serviceType: record.type.name,
      dueDate: record.nextDueDate!,
    );
  }
}
