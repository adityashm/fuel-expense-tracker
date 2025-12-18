import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Helper for database backup and migration safety
class DatabaseBackupHelper {
  DatabaseBackupHelper._();
  static final DatabaseBackupHelper instance = DatabaseBackupHelper._();

  /// Create a backup before migration
  Future<String?> createBackupBeforeMigration(Database db) async {
    try {
      final dbPath = await getDatabasesPath();
      final sourcePath = join(dbPath, 'fuel_tracker.db');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = join(dbPath, 'fuel_tracker_backup_$timestamp.db');

      // Copy database file
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        await sourceFile.copy(backupPath);
        debugPrint('✅ Database backup created: $backupPath');
        return backupPath;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Failed to create database backup: $e');
      return null;
    }
  }

  /// Restore from backup
  Future<bool> restoreFromBackup(String backupPath) async {
    try {
      final dbPath = await getDatabasesPath();
      final targetPath = join(dbPath, 'fuel_tracker.db');

      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.copy(targetPath);
        debugPrint('✅ Database restored from backup: $backupPath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Failed to restore from backup: $e');
      return false;
    }
  }

  /// Validate database integrity after migration
  Future<bool> validateDatabaseIntegrity(Database db) async {
    try {
      // Check integrity
      final result = await db.rawQuery('PRAGMA integrity_check');
      if (result.isEmpty || result.first.values.first != 'ok') {
        debugPrint('❌ Database integrity check failed');
        return false;
      }

      // Check if critical tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      final criticalTables = {
        'vehicles',
        'fuel_expenses',
        'general_expenses',
        'devices',
      };

      if (!criticalTables.every(tableNames.contains)) {
        debugPrint('❌ Critical tables missing after migration');
        return false;
      }

      debugPrint('✅ Database validation passed');
      return true;
    } catch (e) {
      debugPrint('❌ Database validation error: $e');
      return false;
    }
  }

  /// Clean old backups (keep last 5)
  Future<void> cleanOldBackups() async {
    try {
      final dbPath = await getDatabasesPath();
      final dir = Directory(dbPath);

      final backupFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => basename(f.path).startsWith('fuel_tracker_backup_'))
          .toList();

      if (backupFiles.length <= 5) return;

      // Sort by modification time
      backupFiles.sort(
        (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
      );

      // Delete oldest files
      for (var i = 0; i < backupFiles.length - 5; i++) {
        await backupFiles[i].delete();
        debugPrint('🗑️ Deleted old backup: ${basename(backupFiles[i].path)}');
      }
    } catch (e) {
      debugPrint('Warning: Failed to clean old backups: $e');
    }
  }
}
