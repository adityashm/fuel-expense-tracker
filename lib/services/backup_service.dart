import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();
  static const _keyStorageKey = 'backup_encryption_key';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<File> createEncryptedBackup() async {
    final export = await _collectData();
    final payload = jsonEncode(export);
    final encryptedBytes = await _encrypt(payload);

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'fuel_tracker_${DateTime.now().millisecondsSinceEpoch}.backup';
    final file = File(path.join(dir.path, fileName));
    await file.writeAsBytes(encryptedBytes, flush: true);
    return file;
  }

  Future<void> restoreEncryptedBackup(File file) async {
    final bytes = await file.readAsBytes();
    final decrypted = await _decrypt(bytes);
    final data = jsonDecode(decrypted) as Map<String, dynamic>;
    final tables = Map<String, dynamic>.from(data['tables'] as Map);
    final db = await DatabaseService.instance.database;

    await db.transaction((txn) async {
      for (final table in tables.keys) {
        await txn.delete(table);
      }
      for (final entry in tables.entries) {
        final rows = List<Map<String, dynamic>>.from(entry.value as List);
        for (final row in rows) {
          await txn.insert(
            entry.key,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<Map<String, dynamic>> _collectData() async {
    final db = await DatabaseService.instance.database;
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
      'generated_at': DateTime.now().toIso8601String(),
      'tables': tables,
    };
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
}
