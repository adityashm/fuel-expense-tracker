class DeviceConnection {
  const DeviceConnection({
    this.id,
    required this.ownerDeviceId,
    required this.friendDeviceId,
    required this.friendName,
    required this.createdAt,
  });

  factory DeviceConnection.fromMap(Map<String, dynamic> map) {
    return DeviceConnection(
      id: map['id'] as int?,
      ownerDeviceId: map['owner_device_id'] as String,
      friendDeviceId: map['friend_device_id'] as String,
      friendName: map['friend_name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
  final int? id;
  final String ownerDeviceId;
  final String friendDeviceId;
  final String friendName;
  final DateTime createdAt;

  DeviceConnection copyWith({
    int? id,
    String? ownerDeviceId,
    String? friendDeviceId,
    String? friendName,
    DateTime? createdAt,
  }) {
    return DeviceConnection(
      id: id ?? this.id,
      ownerDeviceId: ownerDeviceId ?? this.ownerDeviceId,
      friendDeviceId: friendDeviceId ?? this.friendDeviceId,
      friendName: friendName ?? this.friendName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_device_id': ownerDeviceId,
      'friend_device_id': friendDeviceId,
      'friend_name': friendName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
