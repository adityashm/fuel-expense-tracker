class Achievement {
  Achievement({
    this.id,
    required this.deviceId,
    required this.badgeKey,
    required this.label,
    this.description,
    this.points = 0,
    DateTime? earnedAt,
  }) : earnedAt = earnedAt ?? DateTime.now();

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] as int?,
      deviceId: map['device_id'] as String,
      badgeKey: map['badge_key'] as String,
      label: map['label'] as String,
      description: map['description'] as String?,
      points: (map['points'] as int?) ?? 0,
      earnedAt: DateTime.parse(map['earned_at'] as String),
    );
  }
  final int? id;
  final String deviceId;
  final String badgeKey;
  final String label;
  final String? description;
  final int points;
  final DateTime earnedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'badge_key': badgeKey,
      'label': label,
      'description': description,
      'points': points,
      'earned_at': earnedAt.toIso8601String(),
    };
  }
}
