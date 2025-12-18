import 'package:geolocator/geolocator.dart';

class StationGeofence {
  StationGeofence({
    this.id,
    required this.stationId,
    required this.stationName,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 100.0,
    this.isEnabled = true,
    required this.createdAt,
    this.lastTriggeredAt,
    this.triggerCount = 0,
  });

  factory StationGeofence.fromMap(Map<String, dynamic> map) {
    return StationGeofence(
      id: map['id'] as int?,
      stationId: map['station_id'] as int? ?? 0,
      stationName: map['station_name'] as String? ?? 'Unknown Station',
      latitude: (map['latitude'] as num? ?? 0).toDouble(),
      longitude: (map['longitude'] as num? ?? 0).toDouble(),
      radiusMeters: (map['radius_meters'] as num? ?? 100.0).toDouble(),
      isEnabled: (map['is_enabled'] as int? ?? 1) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      lastTriggeredAt: map['last_triggered_at'] != null
          ? DateTime.parse(map['last_triggered_at'] as String)
          : null,
      triggerCount: map['trigger_count'] as int? ?? 0,
    );
  }
  final int? id;
  final int stationId; // Links to FavoriteStation
  final String stationName;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? lastTriggeredAt;
  final int triggerCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'station_id': stationId,
      'station_name': stationName,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'is_enabled': isEnabled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'last_triggered_at': lastTriggeredAt?.toIso8601String(),
      'trigger_count': triggerCount,
    };
  }

  // Check if position is within geofence
  bool containsPosition(Position position) {
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      position.latitude,
      position.longitude,
    );
    return distance <= radiusMeters;
  }

  // Get distance from position to geofence center
  double distanceFrom(Position position) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      position.latitude,
      position.longitude,
    );
  }

  StationGeofence copyWith({
    int? id,
    int? stationId,
    String? stationName,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? lastTriggeredAt,
    int? triggerCount,
  }) {
    return StationGeofence(
      id: id ?? this.id,
      stationId: stationId ?? this.stationId,
      stationName: stationName ?? this.stationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      triggerCount: triggerCount ?? this.triggerCount,
    );
  }
}

class GeofenceEvent {
  GeofenceEvent({
    this.id,
    required this.geofenceId,
    required this.stationName,
    required this.eventType,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.notificationShown = false,
    this.expenseLogged = false,
    this.expenseId,
  });

  factory GeofenceEvent.fromMap(Map<String, dynamic> map) {
    return GeofenceEvent(
      id: map['id'] as int?,
      geofenceId: map['geofence_id'] as int,
      stationName: map['station_name'] as String,
      eventType: GeofenceEventType.values[map['event_type'] as int],
      timestamp: DateTime.parse(map['timestamp'] as String),
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      notificationShown: (map['notification_shown'] as int) == 1,
      expenseLogged: (map['expense_logged'] as int) == 1,
      expenseId: map['expense_id'] as int?,
    );
  }
  final int? id;
  final int geofenceId;
  final String stationName;
  final GeofenceEventType eventType;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final bool notificationShown;
  final bool expenseLogged;
  final int? expenseId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'geofence_id': geofenceId,
      'station_name': stationName,
      'event_type': eventType.index,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'notification_shown': notificationShown ? 1 : 0,
      'expense_logged': expenseLogged ? 1 : 0,
      'expense_id': expenseId,
    };
  }

  GeofenceEvent copyWith({
    int? id,
    int? geofenceId,
    String? stationName,
    GeofenceEventType? eventType,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    bool? notificationShown,
    bool? expenseLogged,
    int? expenseId,
  }) {
    return GeofenceEvent(
      id: id ?? this.id,
      geofenceId: geofenceId ?? this.geofenceId,
      stationName: stationName ?? this.stationName,
      eventType: eventType ?? this.eventType,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notificationShown: notificationShown ?? this.notificationShown,
      expenseLogged: expenseLogged ?? this.expenseLogged,
      expenseId: expenseId ?? this.expenseId,
    );
  }
}

enum GeofenceEventType {
  enter,
  exit,
  dwell,
}

class GeofenceSettings {
  GeofenceSettings({
    this.geofencingEnabled = true,
    this.backgroundLocationEnabled = false,
    this.notificationsEnabled = true,
    this.exitRemindersEnabled = true,
    this.exitReminderDelayMinutes = 5,
    this.debounceHours = 2,
    this.quietHourStart = 22,
    this.quietHourEnd = 6,
    this.defaultRadiusMeters = 100.0,
  });

  factory GeofenceSettings.fromMap(Map<String, dynamic> map) {
    return GeofenceSettings(
      geofencingEnabled: (map['geofencing_enabled'] as int?) == 1,
      backgroundLocationEnabled:
          (map['background_location_enabled'] as int?) == 1,
      notificationsEnabled: (map['notifications_enabled'] as int?) == 1,
      exitRemindersEnabled: (map['exit_reminders_enabled'] as int?) == 1,
      exitReminderDelayMinutes: map['exit_reminder_delay_minutes'] as int? ?? 5,
      debounceHours: map['debounce_hours'] as int? ?? 2,
      quietHourStart: map['quiet_hour_start'] as int? ?? 22,
      quietHourEnd: map['quiet_hour_end'] as int? ?? 6,
      defaultRadiusMeters: map['default_radius_meters'] as double? ?? 100.0,
    );
  }
  final bool geofencingEnabled;
  final bool backgroundLocationEnabled;
  final bool notificationsEnabled;
  final bool exitRemindersEnabled;
  final int exitReminderDelayMinutes;
  final int debounceHours;
  final int quietHourStart; // 22 (10 PM)
  final int quietHourEnd; // 6 (6 AM)
  final double defaultRadiusMeters;

  Map<String, dynamic> toMap() {
    return {
      'geofencing_enabled': geofencingEnabled ? 1 : 0,
      'background_location_enabled': backgroundLocationEnabled ? 1 : 0,
      'notifications_enabled': notificationsEnabled ? 1 : 0,
      'exit_reminders_enabled': exitRemindersEnabled ? 1 : 0,
      'exit_reminder_delay_minutes': exitReminderDelayMinutes,
      'debounce_hours': debounceHours,
      'quiet_hour_start': quietHourStart,
      'quiet_hour_end': quietHourEnd,
      'default_radius_meters': defaultRadiusMeters,
    };
  }

  bool isQuietHour(DateTime time) {
    final hour = time.hour;
    if (quietHourStart < quietHourEnd) {
      return hour >= quietHourStart && hour < quietHourEnd;
    } else {
      // Spans midnight
      return hour >= quietHourStart || hour < quietHourEnd;
    }
  }

  GeofenceSettings copyWith({
    bool? geofencingEnabled,
    bool? backgroundLocationEnabled,
    bool? notificationsEnabled,
    bool? exitRemindersEnabled,
    int? exitReminderDelayMinutes,
    int? debounceHours,
    int? quietHourStart,
    int? quietHourEnd,
    double? defaultRadiusMeters,
  }) {
    return GeofenceSettings(
      geofencingEnabled: geofencingEnabled ?? this.geofencingEnabled,
      backgroundLocationEnabled:
          backgroundLocationEnabled ?? this.backgroundLocationEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      exitRemindersEnabled: exitRemindersEnabled ?? this.exitRemindersEnabled,
      exitReminderDelayMinutes:
          exitReminderDelayMinutes ?? this.exitReminderDelayMinutes,
      debounceHours: debounceHours ?? this.debounceHours,
      quietHourStart: quietHourStart ?? this.quietHourStart,
      quietHourEnd: quietHourEnd ?? this.quietHourEnd,
      defaultRadiusMeters: defaultRadiusMeters ?? this.defaultRadiusMeters,
    );
  }
}

class NearbyStation {
  NearbyStation({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.isFavorite = false,
    this.favoriteStationId,
  });
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final bool isFavorite;
  final int? favoriteStationId;

  String get distanceDisplay {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)}m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
    }
  }
}
