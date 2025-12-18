import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../models/station_geofence.dart' as models;
import 'database_service.dart';
import 'notification_service.dart';

class GeofenceService {
  GeofenceService._init();
  static final GeofenceService instance = GeofenceService._init();
  final _dbService = DatabaseService.instance;
  final _notificationService = NotificationService.instance;

  StreamSubscription<geo.Position>? _positionStreamSubscription;
  final Map<int, GeofenceState> _geofenceStates = {};
  geo.Position? _lastPosition;
  DateTime? _lastNotificationTime;
  models.GeofenceSettings _settings = models.GeofenceSettings();

  // ==================== INITIALIZATION ====================

  Future<void> initialize() async {
    await _loadSettings();
    await _loadGeofenceStates();

    if (_settings.geofencingEnabled) {
      await startMonitoring();
    }
  }

  Future<void> _loadSettings() async {
    final db = await _dbService.database;
    final result = await db.query('location_settings', limit: 1);

    if (result.isNotEmpty) {
      _settings = models.GeofenceSettings.fromMap(result.first);
    } else {
      // Create default settings
      await db.insert('location_settings', _settings.toMap());
    }
  }

  Future<void> _loadGeofenceStates() async {
    final geofences = await getAllGeofences();
    for (final geofence in geofences) {
      _geofenceStates[geofence.id!] = GeofenceState(
        geofence: geofence,
        isInside: false,
      );
    }
  }

  // ==================== LOCATION MONITORING ====================

  Future<void> startMonitoring() async {
    if (!_settings.geofencingEnabled) return;

    // Check permissions
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      debugPrint(
          'GeofenceService: location permission or services not available; monitoring skipped',);
      return;
    }

    // Stop existing subscription
    await stopMonitoring();

    // Configure location settings
    late geo.LocationSettings locationSettings;

    if (_settings.backgroundLocationEnabled) {
      // Battery-efficient background monitoring
      locationSettings = geo.AndroidSettings(
        accuracy: geo.LocationAccuracy.medium,
        distanceFilter: 50, // Update every 50 meters
        intervalDuration: const Duration(minutes: 2),
        foregroundNotificationConfig: const geo.ForegroundNotificationConfig(
          notificationText:
              'Monitoring fuel stations for quick expense logging',
          notificationTitle: 'Fuel Tracker Active',
          enableWakeLock: true,
        ),
      );
    } else {
      // Foreground only
      locationSettings = const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 20,
      );
    }

    // Start geo.Position stream
    _positionStreamSubscription = geo.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (error) {
        debugPrint('Location error: $error');
      },
    );
  }

  Future<void> stopMonitoring() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  Future<bool> _checkLocationPermission() async {
    final bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('GeofenceService: location services disabled');
      return false;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        debugPrint('GeofenceService: location permission denied');
        return false;
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      debugPrint('GeofenceService: location permission permanently denied');
      return false;
    }

    // Request background permission if needed
    if (_settings.backgroundLocationEnabled) {
      // Note: Additional setup needed in AndroidManifest.xml and Info.plist
    }

    return true;
  }

  void _onPositionUpdate(geo.Position position) {
    _lastPosition = position;
    _checkGeofences(position);
  }

  // ==================== GEOFENCE CHECKING ====================

  Future<void> _checkGeofences(geo.Position position) async {
    final now = DateTime.now();

    // Skip during quiet hours
    if (_settings.isQuietHour(now)) {
      return;
    }

    // Check debounce
    if (_lastNotificationTime != null) {
      final hoursSinceLastNotification =
          now.difference(_lastNotificationTime!).inHours;
      if (hoursSinceLastNotification < _settings.debounceHours) {
        return;
      }
    }

    // Check each geofence
    for (final state in _geofenceStates.values) {
      if (!state.geofence.isEnabled) continue;

      final isInside = state.geofence.containsPosition(position);
      final wasInside = state.isInside;

      if (isInside && !wasInside) {
        // ENTER event
        await _handleEnterEvent(state, position, now);
      } else if (!isInside && wasInside) {
        // EXIT event
        await _handleExitEvent(state, position, now);
      }

      // Update state
      _geofenceStates[state.geofence.id!] = state.copyWith(
        isInside: isInside,
        lastEnterTime: isInside && !wasInside ? now : state.lastEnterTime,
        lastExitTime: !isInside && wasInside ? now : state.lastExitTime,
      );
    }
  }

  Future<void> _handleEnterEvent(
    GeofenceState state,
    geo.Position position,
    DateTime now,
  ) async {
    // Log event
    final event = models.GeofenceEvent(
      geofenceId: state.geofence.id!,
      stationName: state.geofence.stationName,
      eventType: models.GeofenceEventType.enter,
      timestamp: now,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    await _logEvent(event);

    // Update trigger count
    await _updateTriggerCount(state.geofence.id!, now);

    // Show notification
    if (_settings.notificationsEnabled) {
      await _showEnterNotification(state.geofence, event.id!);
      _lastNotificationTime = now;
    }
  }

  Future<void> _handleExitEvent(
    GeofenceState state,
    geo.Position position,
    DateTime now,
  ) async {
    // Log event
    final event = models.GeofenceEvent(
      geofenceId: state.geofence.id!,
      stationName: state.geofence.stationName,
      eventType: models.GeofenceEventType.exit,
      timestamp: now,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    await _logEvent(event);

    // Schedule exit reminder
    if (_settings.exitRemindersEnabled) {
      _scheduleExitReminder(state.geofence, event.id!);
    }
  }

  void _scheduleExitReminder(models.StationGeofence geofence, int eventId) {
    Future.delayed(
      Duration(minutes: _settings.exitReminderDelayMinutes),
      () async {
        // Check if expense was logged
        final event = await _getEvent(eventId);
        if (event != null && !event.expenseLogged) {
          await _showExitReminderNotification(geofence, eventId);
        }
      },
    );
  }

  // ==================== NOTIFICATIONS ====================

  Future<void> _showEnterNotification(
    models.StationGeofence geofence,
    int eventId,
  ) async {
    await _notificationService.showNotification(
      id: eventId,
      title: 'At ${geofence.stationName}',
      body: 'Log fuel expense?',
      payload: 'geofence:enter:${geofence.id}:$eventId',
      androidDetails: const AndroidNotificationDetails(
        'geofence',
        'Location Triggers',
        channelDescription: 'Notifications when entering fuel stations',
        importance: Importance.high,
        priority: Priority.high,
        actions: [
          AndroidNotificationAction(
            'quick_add',
            'Quick Add',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'dismiss',
            'Not Now',
          ),
        ],
      ),
    );

    // Update event
    final event = await _getEvent(eventId);
    if (event != null) {
      await _updateEvent(event.copyWith(notificationShown: true));
    }
  }

  Future<void> _showExitReminderNotification(
    models.StationGeofence geofence,
    int eventId,
  ) async {
    await _notificationService.showNotification(
      id: eventId + 10000, // Offset to avoid ID collision
      title: 'Did you refuel at ${geofence.stationName}?',
      body: 'Don\'t forget to log your expense',
      payload: 'geofence:exit_reminder:${geofence.id}:$eventId',
      androidDetails: const AndroidNotificationDetails(
        'geofence_reminder',
        'Exit Reminders',
        channelDescription: 'Reminders to log expense after leaving station',
        actions: [
          AndroidNotificationAction(
            'add_expense',
            'Add Expense',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'dismiss',
            'Dismiss',
          ),
        ],
      ),
    );
  }

  // ==================== DATABASE OPERATIONS ====================

  Future<models.StationGeofence> createGeofence(
    models.StationGeofence geofence,
  ) async {
    final db = await _dbService.database;
    final id = await db.insert('station_geofences', geofence.toMap());

    final created = geofence.copyWith(id: id);
    _geofenceStates[id] = GeofenceState(
      geofence: created,
      isInside: false,
    );

    return created;
  }

  Future<models.StationGeofence> updateGeofence(
    models.StationGeofence geofence,
  ) async {
    final db = await _dbService.database;
    await db.update(
      'station_geofences',
      geofence.toMap(),
      where: 'id = ?',
      whereArgs: [geofence.id],
    );

    if (_geofenceStates.containsKey(geofence.id)) {
      _geofenceStates[geofence.id!] = _geofenceStates[geofence.id!]!.copyWith(
        geofence: geofence,
      );
    }

    return geofence;
  }

  Future<void> deleteGeofence(int id) async {
    final db = await _dbService.database;
    await db.delete('station_geofences', where: 'id = ?', whereArgs: [id]);
    _geofenceStates.remove(id);
  }

  Future<List<models.StationGeofence>> getAllGeofences() async {
    final db = await _dbService.database;
    final maps =
        await db.query('station_geofences', orderBy: 'station_name ASC');
    return maps.map((map) => models.StationGeofence.fromMap(map)).toList();
  }

  Future<List<models.StationGeofence>> getEnabledGeofences() async {
    final db = await _dbService.database;
    final maps = await db.query(
      'station_geofences',
      where: 'is_enabled = ?',
      whereArgs: [1],
      orderBy: 'station_name ASC',
    );
    return maps.map((map) => models.StationGeofence.fromMap(map)).toList();
  }

  Future<models.StationGeofence?> getGeofenceByStationId(int stationId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'station_geofences',
      where: 'station_id = ?',
      whereArgs: [stationId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return models.StationGeofence.fromMap(maps.first);
  }

  Future<void> _updateTriggerCount(int geofenceId, DateTime time) async {
    final db = await _dbService.database;
    await db.rawUpdate(
      '''
      UPDATE station_geofences 
      SET trigger_count = trigger_count + 1,
          last_triggered_at = ?
      WHERE id = ?
    ''',
      [time.toIso8601String(), geofenceId],
    );
  }

  // Event logging
  Future<int> _logEvent(models.GeofenceEvent event) async {
    final db = await _dbService.database;
    return db.insert('geofence_events', event.toMap());
  }

  Future<models.GeofenceEvent?> _getEvent(int id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'geofence_events',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return models.GeofenceEvent.fromMap(maps.first);
  }

  Future<void> _updateEvent(models.GeofenceEvent event) async {
    final db = await _dbService.database;
    await db.update(
      'geofence_events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<void> markExpenseLogged(int eventId, int expenseId) async {
    final event = await _getEvent(eventId);
    if (event != null) {
      await _updateEvent(
        event.copyWith(
          expenseLogged: true,
          expenseId: expenseId,
        ),
      );
    }
  }

  Future<List<models.GeofenceEvent>> getRecentEvents({int limit = 20}) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'geofence_events',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((map) => models.GeofenceEvent.fromMap(map)).toList();
  }

  Future<int> getStationVisitCount(int geofenceId, DateTime since) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM geofence_events
      WHERE geofence_id = ?
        AND event_type = ?
        AND timestamp >= ?
    ''',
      [
        geofenceId,
        models.GeofenceEventType.enter.index,
        since.toIso8601String(),
      ],
    );

    return (result.first['count'] as int?) ?? 0;
  }

  // Settings
  Future<void> updateSettings(models.GeofenceSettings settings) async {
    final db = await _dbService.database;
    await db.update('location_settings', settings.toMap());
    _settings = settings;

    // Restart monitoring with new settings
    if (settings.geofencingEnabled) {
      await startMonitoring();
    } else {
      await stopMonitoring();
    }
  }

  models.GeofenceSettings getSettings() => _settings;

  // ==================== UTILITY METHODS ====================

  Future<geo.Position?> getCurrentPosition() async {
    try {
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) return null;

      return await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Error getting position: $e');
      return null;
    }
  }

  geo.Position? getLastKnownPosition() => _lastPosition;

  Future<List<models.StationGeofence>> getNearbyGeofences({
    double maxDistanceMeters = 5000,
  }) async {
    final position = await getCurrentPosition();
    if (position == null) return [];

    final allGeofences = await getAllGeofences();
    final nearby = allGeofences.where((geofence) {
      final distance = geofence.distanceFrom(position);
      return distance <= maxDistanceMeters;
    }).toList()
      // Sort by distance
      ..sort((a, b) {
        final distA = a.distanceFrom(position);
        final distB = b.distanceFrom(position);
        return distA.compareTo(distB);
      });

    return nearby;
  }

  bool isCurrentlyInsideAnyGeofence() {
    return _geofenceStates.values.any((state) => state.isInside);
  }

  List<models.StationGeofence> getCurrentGeofences() {
    return _geofenceStates.values
        .where((state) => state.isInside)
        .map((state) => state.geofence)
        .toList();
  }

  // Cleanup
  Future<void> dispose() async {
    await stopMonitoring();
    _geofenceStates.clear();
  }
}

// Helper class to track geofence state
class GeofenceState {
  GeofenceState({
    required this.geofence,
    required this.isInside,
    this.lastEnterTime,
    this.lastExitTime,
  });
  final models.StationGeofence geofence;
  final bool isInside;
  final DateTime? lastEnterTime;
  final DateTime? lastExitTime;

  GeofenceState copyWith({
    models.StationGeofence? geofence,
    bool? isInside,
    DateTime? lastEnterTime,
    DateTime? lastExitTime,
  }) {
    return GeofenceState(
      geofence: geofence ?? this.geofence,
      isInside: isInside ?? this.isInside,
      lastEnterTime: lastEnterTime ?? this.lastEnterTime,
      lastExitTime: lastExitTime ?? this.lastExitTime,
    );
  }
}
