// ignore_for_file: avoid_slow_async_io

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';
import 'firebase_service.dart';

/// Backup metadata
class BackupInfo {
  BackupInfo({
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
    required this.type,
    this.cloudId,
    required this.recordCount,
  });

  factory BackupInfo.fromMap(Map<String, dynamic> map) => BackupInfo(
        fileName: map['fileName'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        sizeBytes: map['sizeBytes'] as int,
        type: BackupType.values.byName(map['type'] as String),
        cloudId: map['cloudId'] as String?,
        recordCount: map['recordCount'] as int,
      );
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;
  final BackupType type;
  final String? cloudId;
  final int recordCount;

  Map<String, dynamic> toMap() => {
        'fileName': fileName,
        'createdAt': createdAt.toIso8601String(),
        'sizeBytes': sizeBytes,
        'type': type.name,
        'cloudId': cloudId,
        'recordCount': recordCount,
      };

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

enum BackupType {
  auto,
  manual,
  preUpdate,
  cloud,
}

/// Backup settings
class BackupSettings {
  BackupSettings({
    this.autoBackupEnabled = true,
    this.autoBackupIntervalDays = 7,
    this.maxLocalBackups = 5,
    this.cloudBackupEnabled = false,
    this.maxCloudBackups = 3,
  });

  factory BackupSettings.fromMap(Map<String, dynamic> map) => BackupSettings(
        autoBackupEnabled: map['autoBackupEnabled'] as bool? ?? true,
        autoBackupIntervalDays: map['autoBackupIntervalDays'] as int? ?? 7,
        maxLocalBackups: map['maxLocalBackups'] as int? ?? 5,
        cloudBackupEnabled: map['cloudBackupEnabled'] as bool? ?? false,
        maxCloudBackups: map['maxCloudBackups'] as int? ?? 3,
      );
  final bool autoBackupEnabled;
  final int autoBackupIntervalDays;
  final int maxLocalBackups;
  final bool cloudBackupEnabled;
  final int maxCloudBackups;

  Map<String, dynamic> toMap() => {
        'autoBackupEnabled': autoBackupEnabled,
        'autoBackupIntervalDays': autoBackupIntervalDays,
        'maxLocalBackups': maxLocalBackups,
        'cloudBackupEnabled': cloudBackupEnabled,
        'maxCloudBackups': maxCloudBackups,
      };
}

/// Enhanced backup service with auto-backup and cloud support
class EnhancedBackupService {
  EnhancedBackupService._();

  static final EnhancedBackupService instance = EnhancedBackupService._();
  static const _keyStorageKey = 'backup_encryption_key_v2';
  static const _settingsKey = 'backup_settings';
  static const _historyKey = 'backup_history';
  static const _lastAutoBackupKey = 'last_auto_backup';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final _db = DatabaseService.instance;
  final _firebase = FirebaseService.instance;

  Timer? _autoBackupTimer;
  BackupSettings _settings = BackupSettings();
  final List<BackupInfo> _backupHistory = [];

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  /// Initialize the service
  Future<void> initialize() async {
    await _loadSettings();
    await _loadHistory();

    if (_settings.autoBackupEnabled) {
      _scheduleAutoBackup();
    }
  }

  /// Get current settings
  BackupSettings get settings => _settings;

  /// Update settings
  Future<void> updateSettings(BackupSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();

    if (newSettings.autoBackupEnabled) {
      _scheduleAutoBackup();
    } else {
      _autoBackupTimer?.cancel();
    }
  }

  /// Get backup history
  List<BackupInfo> get backupHistory => List.unmodifiable(_backupHistory);

  /// Schedule auto backup check
  void _scheduleAutoBackup() {
    _autoBackupTimer?.cancel();
    // Check every hour if backup is needed
    _autoBackupTimer = Timer.periodic(const Duration(hours: 1), (_) async {
      await _checkAndPerformAutoBackup();
    });

    // Also check immediately
    _checkAndPerformAutoBackup();
  }

  Future<void> _checkAndPerformAutoBackup() async {
    if (!_settings.autoBackupEnabled) return;

    final prefs = await SharedPreferences.getInstance();
    final lastBackupStr = prefs.getString(_lastAutoBackupKey);
    final lastBackup =
        lastBackupStr != null ? DateTime.parse(lastBackupStr) : null;

    if (lastBackup == null ||
        DateTime.now().difference(lastBackup).inDays >=
            _settings.autoBackupIntervalDays) {
      debugPrint('Performing auto backup...');
      await createBackup(type: BackupType.auto);
    }
  }

  /// Create an encrypted backup
  Future<BackupInfo?> createBackup({
    BackupType type = BackupType.manual,
    bool uploadToCloud = false,
  }) async {
    try {
      _statusController.add('Creating backup...');

      final export = await _collectData();
      final payload = jsonEncode(export);
      final encryptedBytes = await _encrypt(payload);
      final recordCount = _countRecords(export);

      // Generate filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final typePrefix = type == BackupType.auto
          ? 'auto'
          : type == BackupType.preUpdate
              ? 'preupdate'
              : 'manual';
      final fileName = 'fuel_tracker_${typePrefix}_$timestamp.backup';

      // Save to local storage
      final dir = await _getBackupDirectory();
      final file = File(path.join(dir.path, fileName));
      await file.writeAsBytes(encryptedBytes, flush: true);

      String? cloudId;
      if ((uploadToCloud || _settings.cloudBackupEnabled) &&
          _firebase.userId != null) {
        _statusController.add('Uploading to cloud...');
        cloudId = await _uploadToCloud(file, fileName);
      }

      // Create backup info
      final info = BackupInfo(
        fileName: fileName,
        createdAt: DateTime.now(),
        sizeBytes: encryptedBytes.length,
        type: type,
        cloudId: cloudId,
        recordCount: recordCount,
      );

      // Add to history
      _backupHistory.insert(0, info);
      await _saveHistory();

      // Cleanup old backups
      await _cleanupOldBackups();

      // Update last auto backup time
      if (type == BackupType.auto) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            _lastAutoBackupKey, DateTime.now().toIso8601String(),);
      }

      _statusController.add('Backup created successfully');
      return info;
    } catch (e) {
      _statusController.add('Backup failed: $e');
      debugPrint('Backup error: $e');
      return null;
    }
  }

  /// Create a pre-update backup (before app updates)
  Future<BackupInfo?> createPreUpdateBackup() async {
    return createBackup(type: BackupType.preUpdate, uploadToCloud: true);
  }

  /// Restore from a backup file
  Future<bool> restoreBackup(String fileName) async {
    try {
      _statusController.add('Restoring backup...');

      final dir = await _getBackupDirectory();
      final file = File(path.join(dir.path, fileName));

      if (!await file.exists()) {
        _statusController.add('Backup file not found');
        return false;
      }

      final bytes = await file.readAsBytes();
      final decrypted = await _decrypt(bytes);
      final data = jsonDecode(decrypted) as Map<String, dynamic>;

      await _restoreData(data);

      _statusController.add('Restore completed successfully');
      return true;
    } catch (e) {
      _statusController.add('Restore failed: $e');
      debugPrint('Restore error: $e');
      return false;
    }
  }

  /// Restore from cloud backup
  Future<bool> restoreFromCloud(String cloudId) async {
    try {
      _statusController.add('Downloading from cloud...');

      final bytes = await _downloadFromCloud(cloudId);
      if (bytes == null) {
        _statusController.add('Cloud backup not found');
        return false;
      }

      _statusController.add('Restoring backup...');
      final decrypted = await _decrypt(bytes);
      final data = jsonDecode(decrypted) as Map<String, dynamic>;

      await _restoreData(data);

      _statusController.add('Restore completed successfully');
      return true;
    } catch (e) {
      _statusController.add('Cloud restore failed: $e');
      debugPrint('Cloud restore error: $e');
      return false;
    }
  }

  /// Delete a backup
  Future<bool> deleteBackup(String fileName) async {
    try {
      final dir = await _getBackupDirectory();
      final file = File(path.join(dir.path, fileName));

      if (await file.exists()) {
        await file.delete();
      }

      _backupHistory.removeWhere((info) => info.fileName == fileName);
      await _saveHistory();

      return true;
    } catch (e) {
      debugPrint('Delete backup error: $e');
      return false;
    }
  }

  /// Get list of available backups
  Future<List<BackupInfo>> getAvailableBackups() async {
    final dir = await _getBackupDirectory();
    final files = await dir.list().toList();
    final backups = <BackupInfo>[];

    for (final entity in files) {
      if (entity is File && entity.path.endsWith('.backup')) {
        final stat = await entity.stat();
        final fileName = path.basename(entity.path);

        // Find in history or create basic info
        final historyInfo = _backupHistory.cast<BackupInfo?>().firstWhere(
              (info) => info?.fileName == fileName,
              orElse: () => null,
            );

        if (historyInfo != null) {
          backups.add(historyInfo);
        } else {
          backups.add(
            BackupInfo(
              fileName: fileName,
              createdAt: stat.modified,
              sizeBytes: stat.size,
              type: BackupType.manual,
              recordCount: 0,
            ),
          );
        }
      }
    }

    // Sort by date, newest first
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  /// Get cloud backups
  Future<List<BackupInfo>> getCloudBackups() async {
    if (_firebase.userId == null) return [];

    try {
      // Cloud backup feature - to be implemented when Firebase Storage is ready
      // For now, return empty list
      return [];
    } catch (e) {
      debugPrint('Get cloud backups error: $e');
      return [];
    }
  }

  /// Export backup to shareable location
  Future<File?> exportBackup(String fileName) async {
    try {
      final dir = await _getBackupDirectory();
      final sourceFile = File(path.join(dir.path, fileName));

      if (!await sourceFile.exists()) {
        return null;
      }

      // Copy to downloads/external storage
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) return null;

      final destFile = File(path.join(externalDir.path, fileName));
      return await sourceFile.copy(destFile.path);
    } catch (e) {
      debugPrint('Export backup error: $e');
      return null;
    }
  }

  /// Import backup from external file
  Future<bool> importBackup(File externalFile) async {
    try {
      // Validate the file
      final bytes = await externalFile.readAsBytes();
      await _decrypt(bytes); // Will throw if invalid

      // Copy to backup directory
      final dir = await _getBackupDirectory();
      final destFile =
          File(path.join(dir.path, path.basename(externalFile.path)));
      await externalFile.copy(destFile.path);

      return true;
    } catch (e) {
      debugPrint('Import backup error: $e');
      return false;
    }
  }

  // Private methods

  Future<Directory> _getBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(path.join(appDir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<Map<String, dynamic>> _collectData() async {
    final db = await _db.database;
    final tables = <String, List<Map<String, dynamic>>>{};
    const tableNames = [
      'devices',
      'vehicles',
      'vehicle_access',
      'fuel_expenses',
      'general_expenses',
      'maintenance_records',
      'activity_logs',
      'expense_comments',
      'settlements',
      'reminders',
      'budgets',
      'trips',
      'community_posts',
      'achievements',
      'automation_endpoints',
    ];

    for (final table in tableNames) {
      try {
        final rows = await db.query(table);
        tables[table] = rows;
      } catch (_) {
        // Table might not exist yet; skip silently
      }
    }

    return {
      'version': await db.getVersion(),
      'app_version': '2.5.0',
      'generated_at': DateTime.now().toIso8601String(),
      'device_id': await _getDeviceId(),
      'tables': tables,
    };
  }

  int _countRecords(Map<String, dynamic> data) {
    int count = 0;
    final tables = data['tables'] as Map<String, dynamic>?;
    if (tables != null) {
      for (final rows in tables.values) {
        if (rows is List) {
          count += rows.length;
        }
      }
    }
    return count;
  }

  Future<void> _restoreData(Map<String, dynamic> data) async {
    final tables = Map<String, dynamic>.from(data['tables'] as Map);
    final db = await _db.database;

    await db.transaction((txn) async {
      // Clear existing data
      for (final table in tables.keys) {
        try {
          await txn.delete(table);
        } catch (_) {
          // Table might not exist
        }
      }

      // Insert new data
      for (final entry in tables.entries) {
        final rows = List<Map<String, dynamic>>.from(entry.value as List);
        for (final row in rows) {
          try {
            await txn.insert(
              entry.key,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            debugPrint('Insert error for ${entry.key}: $e');
          }
        }
      }
    });
  }

  Future<List<int>> _encrypt(String input) async {
    final key = await _getOrCreateKey();
    final rawKey = encrypt.Key.fromBase64(key);
    final iv = encrypt.IV.fromSecureRandom(16);
    final aes =
        encrypt.Encrypter(encrypt.AES(rawKey, mode: encrypt.AESMode.cbc));
    final encrypted = aes.encrypt(input, iv: iv);
    return iv.bytes + encrypted.bytes;
  }

  Future<String> _decrypt(List<int> bytes) async {
    if (bytes.length < 16) {
      throw const FormatException('Backup file is corrupted');
    }
    final ivBytes = bytes.sublist(0, 16);
    final cipherBytes = bytes.sublist(16);
    final key = await _getOrCreateKey();
    final aes = encrypt.Encrypter(
      encrypt.AES(encrypt.Key.fromBase64(key), mode: encrypt.AESMode.cbc),
    );
    final decrypted = aes.decryptBytes(
      encrypt.Encrypted(Uint8List.fromList(cipherBytes)),
      iv: encrypt.IV(Uint8List.fromList(ivBytes)),
    );
    return utf8.decode(decrypted);
  }

  Future<String> _getOrCreateKey() async {
    final cached = await _secureStorage.read(key: _keyStorageKey);
    if (cached != null) {
      return cached;
    }
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final encoded = base64Encode(keyBytes);
    await _secureStorage.write(key: _keyStorageKey, value: encoded);
    return encoded;
  }

  Future<String?> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_id');
  }

  Future<String?> _uploadToCloud(File file, String fileName) async {
    try {
      // Cloud backup feature - to be implemented when Firebase Storage is ready
      // For now, skip cloud upload
      debugPrint('Cloud backup not yet implemented');
      return null;
    } catch (e) {
      debugPrint('Upload to cloud error: $e');
      return null;
    }
  }

  Future<List<int>?> _downloadFromCloud(String cloudId) async {
    try {
      // Cloud restore feature - to be implemented when Firebase Storage is ready
      debugPrint('Cloud restore not yet implemented');
      return null;
    } catch (e) {
      debugPrint('Download from cloud error: $e');
      return null;
    }
  }

  Future<void> _cleanupOldBackups() async {
    final backups = await getAvailableBackups();

    // Keep only maxLocalBackups
    final localBackups =
        backups.where((b) => b.type != BackupType.cloud).toList();
    if (localBackups.length > _settings.maxLocalBackups) {
      final toDelete = localBackups.sublist(_settings.maxLocalBackups);
      for (final backup in toDelete) {
        await deleteBackup(backup.fileName);
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    if (settingsJson != null) {
      _settings = BackupSettings.fromMap(
          jsonDecode(settingsJson) as Map<String, dynamic>,);
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(_settings.toMap()));
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey) ?? [];

    _backupHistory.clear();
    for (final json in historyJson) {
      try {
        _backupHistory
            .add(BackupInfo.fromMap(jsonDecode(json) as Map<String, dynamic>));
      } catch (_) {}
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson =
        _backupHistory.map((info) => jsonEncode(info.toMap())).toList();
    await prefs.setStringList(_historyKey, historyJson);
  }

  void dispose() {
    _autoBackupTimer?.cancel();
    _statusController.close();
  }
}
