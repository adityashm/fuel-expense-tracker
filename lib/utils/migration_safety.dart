import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/database_backup_helper.dart';
import '../utils/query_cache.dart';

/// Enhanced database migration wrapper
/// Adds backup, validation, and rollback capabilities to migrations
class MigrationSafetyWrapper {
  /// Execute migration with safety checks
  static Future<void> executeSafeMigration(
    Database db,
    int oldVersion,
    int newVersion,
    Future<void> Function(Transaction txn) migrationLogic,
  ) async {
    final backupHelper = DatabaseBackupHelper.instance;
    String? backupPath;

    try {
      // Step 1: Create backup before migration
      debugPrint('🔄 Creating database backup before migration v$oldVersion → v$newVersion');
      backupPath = await backupHelper.createBackupBeforeMigration(db);

      if (backupPath != null) {
        debugPrint('✅ Backup created: $backupPath');
      } else {
        debugPrint('⚠️ Warning: Could not create backup');
      }

      // Step 2: Execute migration in transaction
      debugPrint('🔄 Executing migration v$oldVersion → v$newVersion');
      await db.transaction((txn) async {
        await migrationLogic(txn);
      });

      // Step 3: Validate database integrity
      debugPrint('🔍 Validating database integrity...');
      final isValid = await backupHelper.validateDatabaseIntegrity(db);

      if (!isValid) {
        throw Exception('Database validation failed after migration');
      }

      debugPrint('✅ Migration v$oldVersion → v$newVersion completed successfully');

      // Step 4: Clear all caches after successful migration
      QueryCache.instance.clearAll();
      debugPrint('🗑️ Query cache cleared after migration');

      // Step 5: Clean old backups
      await backupHelper.cleanOldBackups();
    } catch (e, stackTrace) {
      debugPrint('❌ Migration failed: $e');
      debugPrint('Stack trace: $stackTrace');

      // Attempt to restore from backup
      if (backupPath != null) {
        debugPrint('🔄 Attempting to restore from backup...');
        final restored = await backupHelper.restoreFromBackup(backupPath);

        if (restored) {
          debugPrint('✅ Database restored from backup');
        } else {
          debugPrint('❌ Failed to restore database from backup');
        }
      }

      // Rethrow to let caller know migration failed
      rethrow;
    }
  }
}

/// Migration utility methods
class MigrationHelpers {
  /// Safely add column if it doesn't exist
  static Future<void> addColumnIfMissing(
    Transaction txn,
    String table,
    String column,
    String definition,
  ) async {
    try {
      final tableInfo = await txn.rawQuery('PRAGMA table_info($table)');
      final hasColumn = tableInfo.any((col) => col['name'] == column);

      if (!hasColumn) {
        await txn.execute('ALTER TABLE $table ADD COLUMN $column $definition');
        debugPrint('✅ Added column: $table.$column');
      } else {
        debugPrint('⏭️ Column already exists: $table.$column');
      }
    } catch (e) {
      debugPrint('⚠️ Error adding column $table.$column: $e');
      rethrow;
    }
  }

  /// Safely create index if it doesn't exist
  static Future<void> createIndexIfMissing(
    Transaction txn,
    String indexName,
    String createStatement,
  ) async {
    try {
      // Check if index exists
      final indexInfo = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name=?",
        [indexName],
      );

      if (indexInfo.isEmpty) {
        await txn.execute(createStatement);
        debugPrint('✅ Created index: $indexName');
      } else {
        debugPrint('⏭️ Index already exists: $indexName');
      }
    } catch (e) {
      debugPrint('⚠️ Error creating index $indexName: $e');
      // Don't rethrow for indexes - they're performance optimizations
    }
  }

  /// Safely create table if it doesn't exist
  static Future<void> createTableIfMissing(
    Transaction txn,
    String tableName,
    String createStatement,
  ) async {
    try {
      final tableInfo = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );

      if (tableInfo.isEmpty) {
        await txn.execute(createStatement);
        debugPrint('✅ Created table: $tableName');
      } else {
        debugPrint('⏭️ Table already exists: $tableName');
      }
    } catch (e) {
      debugPrint('❌ Error creating table $tableName: $e');
      rethrow;
    }
  }

  /// Batch create indexes for performance
  static Future<void> batchCreateIndexes(
    Transaction txn,
    Map<String, String> indexes,
  ) async {
    for (final entry in indexes.entries) {
      await createIndexIfMissing(txn, entry.key, entry.value);
    }
  }

  /// Check if migration is needed
  static Future<bool> needsMigration(Database db, int targetVersion) async {
    final currentVersion = await db.getVersion();
    return currentVersion < targetVersion;
  }

  /// Get current database version
  static Future<int> getCurrentVersion(Database db) async {
    return db.getVersion();
  }

  /// Validate foreign key constraints
  static Future<bool> validateForeignKeys(Database db) async {
    try {
      final result = await db.rawQuery('PRAGMA foreign_key_check');
      if (result.isNotEmpty) {
        debugPrint('❌ Foreign key violations found: $result');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking foreign keys: $e');
      return false;
    }
  }
}
