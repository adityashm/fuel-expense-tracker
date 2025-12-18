class Device {
  Device({
    this.id,
    required this.deviceId,
    required this.personName,
    this.profilePicturePath,
    this.isActive = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'] as int?,
      deviceId: map['device_id'] as String? ?? '',
      personName: map['person_name'] as String? ?? 'Unknown',
      profilePicturePath: map['profile_picture_path'] as String?,
      isActive: (map['is_active'] as int? ?? 0) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }
  final int? id;
  final String deviceId; // Unique identifier for this device
  final String personName; // Name of the person using this device
  final String? profilePicturePath;
  final bool isActive; // Current device
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'person_name': personName,
      'profile_picture_path': profilePicturePath,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Device copyWith({
    int? id,
    String? deviceId,
    String? personName,
    String? profilePicturePath,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Device(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      personName: personName ?? this.personName,
      profilePicturePath: profilePicturePath ?? this.profilePicturePath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
