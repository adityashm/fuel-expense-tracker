import 'package:sqflite/sqflite.dart';

import '../models/family_member.dart';
import 'database_provider.dart';

/// Repository for family member operations
class FamilyRepository extends DatabaseProvider {
  FamilyRepository._init();
  static final FamilyRepository instance = FamilyRepository._init();

  /// Get family members with pagination
  Future<List<FamilyMember>> getMembers({
    int limit = 50,
    int offset = 0,
    String? deviceId,
    bool? isActive,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

    if (isActive != null) {
      whereClause += ' AND is_active = ?';
      whereArgs.add(isActive ? 1 : 0);
    }

    final maps = await db.query(
      'family_members',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => FamilyMember.fromMap(map)).toList();
  }

  /// Get family member by ID
  Future<FamilyMember?> getMemberById(int id) async {
    final db = await database;
    final maps = await db.query(
      'family_members',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return FamilyMember.fromMap(maps.first);
  }

  /// Insert family member
  Future<int> insertMember(FamilyMember member) async {
    final db = await database;
    return db.insert(
      'family_members',
      member.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update family member
  Future<int> updateMember(FamilyMember member) async {
    final db = await database;
    return db.update(
      'family_members',
      member.toMap(),
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  /// Delete family member
  Future<int> deleteMember(int id) async {
    final db = await database;
    return db.delete(
      'family_members',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get active family members
  Future<List<FamilyMember>> getActiveMembers({String? deviceId}) async {
    return getMembers(
      deviceId: deviceId,
      isActive: true,
      limit: 100, // Get all active members
    );
  }

  /// Search family members by name
  Future<List<FamilyMember>> searchMembers({
    required String query,
    int limit = 20,
  }) async {
    final db = await database;
    final maps = await db.query(
      'family_members',
      where: 'name LIKE ? OR relationship LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
      limit: limit,
    );

    return maps.map((map) => FamilyMember.fromMap(maps.first)).toList();
  }

  /// Get member count
  Future<int> getMemberCount({String? deviceId}) async {
    final db = await database;

    String whereClause = '1=1';
    final List<dynamic> whereArgs = [];

    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM family_members WHERE $whereClause',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Toggle member active status
  Future<int> toggleActiveStatus(int memberId, bool isActive) async {
    final db = await database;
    return db.update(
      'family_members',
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [memberId],
    );
  }

  /// Get unsynced members
  Future<List<FamilyMember>> getUnsyncedMembers({int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      'family_members',
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return maps.map((map) => FamilyMember.fromMap(map)).toList();
  }

  /// Mark member as synced
  Future<int> markAsSynced(int id, String firebaseId) async {
    final db = await database;
    return db.update(
      'family_members',
      {'is_synced': 1, 'firebase_id': firebaseId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get member statistics
  Future<Map<String, dynamic>> getMemberStatistics(int memberId) async {
    final db = await database;

    // Get expense count
    final expenseCount = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM general_expenses
      WHERE device_id = (SELECT device_id FROM family_members WHERE id = ?)
    ''',
      [memberId],
    );

    // Get task count
    final taskCount = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN is_completed = 1 THEN 1 ELSE 0 END) as completed
      FROM family_tasks
      WHERE assigned_to_member_id = ?
    ''',
      [memberId],
    );

    return {
      'expenseCount': expenseCount[0]['count'] ?? 0,
      'totalTasks': taskCount[0]['total'] ?? 0,
      'completedTasks': taskCount[0]['completed'] ?? 0,
    };
  }

  /// Get vehicle preferences for member
  Future<List<Map<String, dynamic>>> getVehiclePreferences(int memberId) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT vmp.*, v.name as vehicle_name
      FROM vehicle_member_preferences vmp
      INNER JOIN vehicles v ON vmp.vehicle_id = v.id
      WHERE vmp.member_id = ?
    ''',
      [memberId],
    );
  }

  /// Update vehicle preferences
  Future<int> updateVehiclePreferences({
    required int vehicleId,
    required int memberId,
    String? defaultFuelType,
    String? preferredStation,
    bool? notificationEnabled,
    bool? canEditVehicle,
    bool? canDeleteExpenses,
  }) async {
    final db = await database;

    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (defaultFuelType != null) data['default_fuel_type'] = defaultFuelType;
    if (preferredStation != null) data['preferred_station'] = preferredStation;
    if (notificationEnabled != null) {
      data['notification_enabled'] = notificationEnabled ? 1 : 0;
    }
    if (canEditVehicle != null) {
      data['can_edit_vehicle'] = canEditVehicle ? 1 : 0;
    }
    if (canDeleteExpenses != null) {
      data['can_delete_expenses'] = canDeleteExpenses ? 1 : 0;
    }

    // Try to update existing preference
    final updated = await db.update(
      'vehicle_member_preferences',
      data,
      where: 'vehicle_id = ? AND member_id = ?',
      whereArgs: [vehicleId, memberId],
    );

    // If no existing preference, insert new one
    if (updated == 0) {
      data['vehicle_id'] = vehicleId;
      data['member_id'] = memberId;
      data['created_at'] = DateTime.now().toIso8601String();
      return db.insert(
        'vehicle_member_preferences',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    return updated;
  }
}
