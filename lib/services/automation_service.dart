import 'dart:async';

import 'package:http/http.dart' as http;

import '../models/automation_endpoint.dart';
import '../providers/device_provider.dart';
import 'database_service.dart';
import 'export_service.dart';

class AutomationService {
  AutomationService._();

  static final AutomationService instance = AutomationService._();
  final DatabaseService _db = DatabaseService.instance;
  final ExportService _exportService = ExportService.instance;
  final http.Client _client = http.Client();

  Future<List<AutomationEndpoint>> fetchEndpoints(String deviceId) async {
    final rows = await _db.getAutomationEndpoints(deviceId);
    return rows.map(AutomationEndpoint.fromMap).toList();
  }

  Future<AutomationEndpoint> createEndpoint({
    required String deviceId,
    required String name,
    required String url,
    Map<String, String> headers = const {},
  }) async {
    final payload = AutomationEndpoint(
      deviceId: deviceId,
      name: name,
      url: url,
      headers: headers,
      createdAt: DateTime.now(),
    );
    final id = await _db.createAutomationEndpoint(payload.toMap());
    return payload.copyWith(id: id);
  }

  Future<void> updateEndpoint(AutomationEndpoint endpoint) async {
    final data = Map<String, dynamic>.from(endpoint.toMap())..remove('id');
    await _db.updateAutomationEndpoint(endpoint.id!, data);
  }

  Future<void> deleteEndpoint(int id) async {
    await _db.deleteAutomationEndpoint(id);
  }

  Future<void> toggleEndpoint(AutomationEndpoint endpoint, bool enabled) async {
    await _db.updateAutomationEndpoint(endpoint.id!, {
      'is_enabled': enabled ? 1 : 0,
    });
  }

  Future<void> triggerEndpoint(AutomationEndpoint endpoint) async {
    final payload = await _exportService.buildJsonSnapshot();
    final uri = Uri.parse(endpoint.url);
    final headers = {
      'Content-Type': 'application/json',
      ...endpoint.headers,
    };

    final response = await _client.post(uri, headers: headers, body: payload);
    if (response.statusCode >= 400) {
      throw Exception('Failed to trigger endpoint (${response.statusCode})');
    }

    await _db.updateAutomationTriggerTime(endpoint.id!, DateTime.now());
  }

  Future<void> broadcastToAll(DeviceProvider deviceProvider) async {
    final snapshot = await _exportService.buildJsonSnapshot();
    final activeDevice = deviceProvider.currentDeviceId;
    if (activeDevice == null) {
      throw Exception('No active device');
    }

    final endpoints = await fetchEndpoints(activeDevice);
    for (final endpoint in endpoints.where((e) => e.isEnabled)) {
      try {
        final uri = Uri.parse(endpoint.url);
        final headers = {
          'Content-Type': 'application/json',
          ...endpoint.headers,
        };
        await _client.post(uri, headers: headers, body: snapshot);
        await _db.updateAutomationTriggerTime(endpoint.id!, DateTime.now());
      } catch (_) {
        // Ignore individual endpoint failures but continue others
      }
    }
  }

  void dispose() {
    _client.close();
  }
}
