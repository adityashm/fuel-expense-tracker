import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'firebase_service.dart';

/// V2.5 Auto-Backup & Cloud Restore Service
/// Handles automatic backups, cloud sync, and data restoration
class V25BackupService {
  factory V25BackupService() => _instance;
  V25BackupService._internal();
  static final V25BackupService _instance = V25BackupService._internal();

  final DatabaseService _db = DatabaseService.instance;
  final FirebaseService _firebase = FirebaseService.instance;

  static const String _lastBackupKey = 'last_backup_timestamp';
  static const String _autoBackupEnabledKey = 'auto_backup_enabled';
  static const Duration _autoBackupInterval = Duration(hours: 24);

  /// Initialize auto-backup
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final autoBackupEnabled = prefs.getBool(_autoBackupEnabledKey) ?? true;

    if (autoBackupEnabled) {
      _scheduleAutoBackup();
    }
  }

  /// Schedule automatic backups
  void _scheduleAutoBackup() {
    Future.doWhile(() async {
      await Future.delayed(_autoBackupInterval);
      try {
        await createAutoBackup();
      } catch (e) {
        debugPrint('Auto-backup failed: $e');
      }
      return true; // Continue scheduling
    });
  }

  /// Create automatic backup
  Future<BackupResult> createAutoBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackupStr = prefs.getString(_lastBackupKey);

    // Check if backup is needed
    if (lastBackupStr != null) {
      final lastBackup = DateTime.parse(lastBackupStr);
      if (DateTime.now().difference(lastBackup) < _autoBackupInterval) {
        return BackupResult(
          success: false,
          message: 'Backup not needed yet',
          timestamp: lastBackup,
        );
      }
    }

    return createBackup(isAutomatic: true);
  }

  /// Create backup (manual or automatic)
  Future<BackupResult> createBackup({bool isAutomatic = false}) async {
    try {
      debugPrint('Creating ${isAutomatic ? 'automatic' : 'manual'} backup...');

      // 1. Export all data from SQLite
      final backupData = await _exportAllData();

      // 2. Save locally
      final localFile = await _saveLocalBackup(backupData);

      // 3. Upload to cloud (if user is signed in)
      String? cloudBackupId;
      if (_firebase.currentUser != null) {
        cloudBackupId = await _uploadToCloud(backupData);
      }

      // 4. Update last backup timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());

      return BackupResult(
        success: true,
        message: 'Backup created successfully',
        timestamp: DateTime.now(),
        localPath: localFile.path,
        cloudBackupId: cloudBackupId,
        dataSize: backupData.length,
      );
    } catch (e) {
      debugPrint('Backup creation failed: $e');
      return BackupResult(
        success: false,
        message: 'Backup failed: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Export all data from database
  Future<Map<String, dynamic>> _exportAllData() async {
    final db = await _db.database;

    // Export all tables
    final fuelExpenses = await db.query('fuel_expenses');
    final generalExpenses = await db.query('general_expenses');
    final vehicles = await db.query('vehicles');
    final trips = await db.query('trips');
    final maintenance = await db.query('maintenance');
    final budgets = await db.query('budgets');
    final reminders = await db.query('reminders');

    return {
      'version': '2.5.0',
      'timestamp': DateTime.now().toIso8601String(),
      'data': {
        'fuel_expenses': fuelExpenses,
        'general_expenses': generalExpenses,
        'vehicles': vehicles,
        'trips': trips,
        'maintenance': maintenance,
        'budgets': budgets,
        'reminders': reminders,
      },
      'stats': {
        'total_expenses': fuelExpenses.length + generalExpenses.length,
        'total_vehicles': vehicles.length,
        'total_trips': trips.length,
      },
    };
  }

  /// Save backup locally
  Future<File> _saveLocalBackup(Map<String, dynamic> data) async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backups');

    if (!backupDir.existsSync()) {
      backupDir.createSync(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'backup_$timestamp.json';
    final file = File('${backupDir.path}/$fileName');

    await file.writeAsString(jsonEncode(data));
    debugPrint('Local backup saved: ${file.path}');

    // Keep only last 7 backups
    await _cleanOldLocalBackups(backupDir);

    return file;
  }

  /// Clean old local backups (keep last 7)
  Future<void> _cleanOldLocalBackups(Directory backupDir) async {
    final files = backupDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    if (files.length <= 7) return;

    // Sort by modification time
    files
        .sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));

    // Delete oldest files
    for (int i = 0; i < files.length - 7; i++) {
      try {
        files[i].deleteSync();
        debugPrint('Deleted old backup: ${files[i].path}');
      } catch (e) {
        debugPrint('Failed to delete old backup: $e');
      }
    }
  }

  /// Upload backup to Firebase Cloud Firestore
  Future<String> _uploadToCloud(Map<String, dynamic> data) async {
    try {
      final userId = _firebase.currentUser?.uid;
      if (userId == null) throw Exception('User not signed in');

      final backupsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('backups');

      // Create backup document
      final docRef = await backupsRef.add({
        'timestamp': FieldValue.serverTimestamp(),
        'version': data['version'],
        'stats': data['stats'],
        'data': data['data'],
        'device_info': {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
        },
      });

      debugPrint('Cloud backup uploaded: ${docRef.id}');

      // Clean old cloud backups (keep last 10)
      await _cleanOldCloudBackups(backupsRef);

      return docRef.id;
    } catch (e) {
      debugPrint('Cloud backup upload failed: $e');
      rethrow;
    }
  }

  /// Clean old cloud backups (keep last 10)
  Future<void> _cleanOldCloudBackups(CollectionReference backupsRef) async {
    try {
      final snapshot =
          await backupsRef.orderBy('timestamp', descending: true).get();

      if (snapshot.docs.length <= 10) return;

      // Delete old backups
      for (int i = 10; i < snapshot.docs.length; i++) {
        await snapshot.docs[i].reference.delete();
        debugPrint('Deleted old cloud backup: ${snapshot.docs[i].id}');
      }
    } catch (e) {
      debugPrint('Failed to clean old cloud backups: $e');
    }
  }

  /// Get list of available backups
  Future<List<BackupInfo>> getAvailableBackups() async {
    final backups = <BackupInfo>[];

    // Get local backups
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/backups');

      if (backupDir.existsSync()) {
        final files = backupDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'));

        for (final file in files) {
          final stat = file.statSync();
          backups.add(
            BackupInfo(
              id: file.path.split('/').last.replaceAll('.json', ''),
              timestamp: stat.modified,
              size: stat.size,
              location: BackupLocation.local,
              path: file.path,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error listing local backups: $e');
    }

    // Get cloud backups
    if (_firebase.currentUser != null) {
      try {
        final userId = _firebase.currentUser?.uid;
        if (userId != null) {
          final snapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('backups')
              .orderBy('timestamp', descending: true)
              .get();

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final timestamp =
                (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

            backups.add(
              BackupInfo(
                id: doc.id,
                timestamp: timestamp,
                size: jsonEncode(data).length,
                location: BackupLocation.cloud,
                cloudId: doc.id,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error listing cloud backups: $e');
      }
    }

    // Sort by timestamp descending
    backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return backups;
  }

  /// Restore from backup
  Future<RestoreResult> restoreFromBackup(BackupInfo backupInfo) async {
    try {
      debugPrint('Restoring backup: ${backupInfo.id}...');

      // 1. Load backup data
      Map<String, dynamic> backupData;
      if (backupInfo.location == BackupLocation.local) {
        backupData = await _loadLocalBackup(backupInfo.path!);
      } else {
        backupData = await _loadCloudBackup(backupInfo.cloudId!);
      }

      // 2. Validate backup data
      if (!_validateBackupData(backupData)) {
        throw Exception('Invalid backup data');
      }

      // 3. Clear existing data
      await _clearAllData();

      // 4. Import backup data
      await _importBackupData(backupData['data']);

      debugPrint('Backup restored successfully');

      final stats = backupData['stats'] as Map<String, dynamic>?;
      final itemsRestored = (stats?['total_expenses'] as num?)?.toInt() ?? 0;

      return RestoreResult(
        success: true,
        message: 'Data restored successfully',
        itemsRestored: itemsRestored,
      );
    } catch (e) {
      debugPrint('Restore failed: $e');
      return RestoreResult(
        success: false,
        message: 'Restore failed: $e',
        itemsRestored: 0,
      );
    }
  }

  /// Load local backup file
  Future<Map<String, dynamic>> _loadLocalBackup(String path) async {
    final file = File(path);
    final contents = await file.readAsString();
    return jsonDecode(contents);
  }

  /// Load cloud backup
  Future<Map<String, dynamic>> _loadCloudBackup(String backupId) async {
    final userId = _firebase.currentUser?.uid;
    if (userId == null) throw Exception('User not signed in');

    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('backups')
        .doc(backupId)
        .get();

    if (!docSnapshot.exists) {
      throw Exception('Backup not found');
    }

    final data = docSnapshot.data()!;
    return {
      'version': data['version'],
      'timestamp': (data['timestamp'] as Timestamp).toDate().toIso8601String(),
      'data': data['data'],
      'stats': data['stats'],
    };
  }

  /// Validate backup data structure
  bool _validateBackupData(Map<String, dynamic> data) {
    return data.containsKey('version') &&
        data.containsKey('data') &&
        data['data'] != null;
  }

  /// Clear all data from database
  Future<void> _clearAllData() async {
    final db = await _db.database;

    await db.delete('fuel_expenses');
    await db.delete('general_expenses');
    await db.delete('vehicles');
    await db.delete('trips');
    await db.delete('maintenance');
    await db.delete('budgets');
    await db.delete('reminders');

    debugPrint('All data cleared');
  }

  /// Import backup data into database
  Future<void> _importBackupData(Map<String, dynamic> data) async {
    final db = await _db.database;

    // Import each table
    for (final entry in data.entries) {
      final tableName = entry.key;
      final records = entry.value as List;

      for (final record in records) {
        await db.insert(tableName, record as Map<String, dynamic>);
      }

      debugPrint('Imported ${records.length} records to $tableName');
    }
  }

  /// Enable/disable auto-backup
  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupEnabledKey, enabled);

    if (enabled) {
      _scheduleAutoBackup();
    }
  }

  /// Get last backup time
  Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackupStr = prefs.getString(_lastBackupKey);

    if (lastBackupStr != null) {
      return DateTime.parse(lastBackupStr);
    }
    return null;
  }
}

/// Backup result
class BackupResult {
  BackupResult({
    required this.success,
    required this.message,
    required this.timestamp,
    this.localPath,
    this.cloudBackupId,
    this.dataSize,
  });

  final bool success;
  final String message;
  final DateTime timestamp;
  final String? localPath;
  final String? cloudBackupId;
  final int? dataSize;
}

/// Restore result
class RestoreResult {
  RestoreResult({
    required this.success,
    required this.message,
    required this.itemsRestored,
  });

  final bool success;
  final String message;
  final int itemsRestored;
}

/// Backup info
class BackupInfo {
  BackupInfo({
    required this.id,
    required this.timestamp,
    required this.size,
    required this.location,
    this.path,
    this.cloudId,
  });

  final String id;
  final DateTime timestamp;
  final int size;
  final BackupLocation location;
  final String? path;
  final String? cloudId;

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Backup location enum
enum BackupLocation {
  local,
  cloud,
}
