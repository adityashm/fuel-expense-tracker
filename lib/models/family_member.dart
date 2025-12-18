class FamilyMember {
  FamilyMember({
    this.id,
    required this.name,
    required this.avatarIcon,
    required this.colorHex,
    this.primaryVehicleId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    return FamilyMember(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'Unknown',
      avatarIcon: map['avatar_icon'] as String? ?? '👤',
      colorHex: map['color_hex'] as int? ?? 0xFF2196F3,
      primaryVehicleId: map['primary_vehicle_id'] as int?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
  final int? id;
  final String name;
  final String avatarIcon;
  final int colorHex;
  final int? primaryVehicleId;
  final DateTime createdAt;

  FamilyMember copyWith({
    int? id,
    String? name,
    String? avatarIcon,
    int? colorHex,
    int? primaryVehicleId,
    DateTime? createdAt,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      colorHex: colorHex ?? this.colorHex,
      primaryVehicleId: primaryVehicleId ?? this.primaryVehicleId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatar_icon': avatarIcon,
      'color_hex': colorHex,
      'primary_vehicle_id': primaryVehicleId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
