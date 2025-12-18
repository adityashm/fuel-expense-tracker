import 'dart:math';

import '../models/integration_token.dart';
import 'database_service.dart';

class IntegrationTokenService {
  IntegrationTokenService._();

  static final IntegrationTokenService instance = IntegrationTokenService._();
  final DatabaseService _db = DatabaseService.instance;
  final Random _random = Random.secure();

  Future<List<IntegrationToken>> fetchTokens(String deviceId) async {
    final rows = await _db.getIntegrationTokens(deviceId);
    return rows.map(IntegrationToken.fromMap).toList();
  }

  Future<IntegrationToken> createToken({
    required String deviceId,
    required String label,
  }) async {
    final token = _generateToken();
    final now = DateTime.now();
    final id = await _db.createIntegrationToken({
      'device_id': deviceId,
      'label': label,
      'token': token,
      'created_at': now.toIso8601String(),
    });
    return IntegrationToken(
      id: id,
      deviceId: deviceId,
      label: label,
      token: token,
      createdAt: now,
    );
  }

  Future<void> renameToken(int id, String newLabel) async {
    await _db.updateIntegrationToken(id, {
      'label': newLabel,
    });
  }

  Future<void> deleteToken(int id) async {
    await _db.deleteIntegrationToken(id);
  }

  Future<void> markTokenUsed(int id) async {
    await _db.updateIntegrationToken(id, {
      'last_used': DateTime.now().toIso8601String(),
    });
  }

  String _generateToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
