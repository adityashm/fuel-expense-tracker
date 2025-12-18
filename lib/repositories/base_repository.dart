import 'package:sqflite/sqflite.dart';

import 'database_provider.dart';

/// Generic repository base class to reduce code duplication
/// All repositories should extend this class
abstract class BaseRepository<T> extends DatabaseProvider {
  /// Table name for this repository
  String get tableName;

  /// Convert map to entity
  T fromMap(Map<String, dynamic> map);

  /// Convert entity to map
  Map<String, dynamic> toMap(T entity);

  /// Get ID from entity (for updates/deletes)
  int? getId(T entity);

  /// Get all records
  Future<List<T>> getAll({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final result = await db.query(
      tableName,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return result.map((map) => fromMap(map)).toList();
  }

  /// Get record by ID
  Future<T?> getById(int id) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return fromMap(result.first);
  }

  /// Get records by condition
  Future<List<T>> getWhere({
    required String where,
    required List<dynamic> whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return result.map((map) => fromMap(map)).toList();
  }

  /// Create new record
  Future<T> create(T entity) async {
    final db = await database;
    final map = toMap(entity)..remove('id'); // Remove ID for insert

    final id = await db.insert(tableName, map);

    // Return entity with new ID
    final created = await getById(id);
    if (created == null) {
      throw Exception('Failed to retrieve created entity');
    }
    return created;
  }

  /// Update existing record
  Future<int> update(T entity) async {
    final id = getId(entity);
    if (id == null) {
      throw ArgumentError('Entity must have an id to update');
    }

    final db = await database;
    return db.update(
      tableName,
      toMap(entity),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete record by ID
  Future<int> delete(int id) async {
    final db = await database;
    return db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Count total records
  Future<int> count({String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    final result = await db.query(
      tableName,
      columns: ['COUNT(*) as count'],
      where: where,
      whereArgs: whereArgs,
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Check if record exists
  Future<bool> exists(int id) async {
    final count = await this.count(where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  /// Batch insert records
  Future<void> batchInsert(List<T> entities) async {
    final db = await database;
    final batch = db.batch();

    for (final entity in entities) {
      final map = toMap(entity)..remove('id');
      batch.insert(tableName, map);
    }

    await batch.commit(noResult: true);
  }

  /// Batch update records
  Future<void> batchUpdate(List<T> entities) async {
    final db = await database;
    final batch = db.batch();

    for (final entity in entities) {
      final id = getId(entity);
      if (id != null) {
        batch.update(
          tableName,
          toMap(entity),
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }

    await batch.commit(noResult: true);
  }

  /// Batch delete records
  Future<void> batchDelete(List<int> ids) async {
    final db = await database;
    final batch = db.batch();

    for (final id in ids) {
      batch.delete(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    await batch.commit(noResult: true);
  }

  /// Execute custom query
  Future<List<T>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    final result = await db.rawQuery(sql, arguments);
    return result.map((map) => fromMap(map)).toList();
  }
}
