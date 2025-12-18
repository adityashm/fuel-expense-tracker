enum AccessType {
  owner,
  contributor,
  viewer,
}

class VehicleAccess {
  VehicleAccess({
    this.id,
    required this.vehicleId,
    required this.deviceId,
    required this.accessType,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory VehicleAccess.fromMap(Map<String, dynamic> map) {
    return VehicleAccess(
      id: map['id'] as int?,
      vehicleId: map['vehicle_id'] as int,
      deviceId: map['device_id'] as String,
      accessType: AccessType.values.firstWhere(
        (e) => e.name == map['access_type'],
        orElse: () => AccessType.viewer,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
  final int? id;
  final int vehicleId;
  final String deviceId;
  final AccessType accessType;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'device_id': deviceId,
      'access_type': accessType.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  VehicleAccess copyWith({
    int? id,
    int? vehicleId,
    String? deviceId,
    AccessType? accessType,
    DateTime? createdAt,
  }) {
    return VehicleAccess(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      deviceId: deviceId ?? this.deviceId,
      accessType: accessType ?? this.accessType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
