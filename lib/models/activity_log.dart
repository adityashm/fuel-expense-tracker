class ActivityLog {
  ActivityLog({
    this.id,
    required this.vehicleId,
    required this.deviceId,
    required this.title,
    required this.description,
    required this.type,
    this.referenceType,
    this.referenceId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'] as int?,
      vehicleId: map['vehicle_id'] as int,
      deviceId: map['device_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      type: map['type'] as String,
      referenceType: map['reference_type'] as String?,
      referenceId: map['reference_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
  final int? id;
  final int vehicleId;
  final String deviceId;
  final String title;
  final String description;
  final String type;
  final String? referenceType;
  final int? referenceId;
  final DateTime createdAt;

  ActivityLog copyWith({
    int? id,
    int? vehicleId,
    String? deviceId,
    String? title,
    String? description,
    String? type,
    String? referenceType,
    int? referenceId,
    DateTime? createdAt,
  }) {
    return ActivityLog(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      deviceId: deviceId ?? this.deviceId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'device_id': deviceId,
      'title': title,
      'description': description,
      'type': type,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
