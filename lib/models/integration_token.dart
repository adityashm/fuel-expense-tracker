class IntegrationToken {
  const IntegrationToken({
    this.id,
    required this.deviceId,
    required this.label,
    required this.token,
    required this.createdAt,
    this.lastUsed,
  });

  factory IntegrationToken.fromMap(Map<String, dynamic> map) {
    return IntegrationToken(
      id: map['id'] as int?,
      deviceId: map['device_id'] as String,
      label: map['label'] as String,
      token: map['token'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastUsed: map['last_used'] != null
          ? DateTime.parse(map['last_used'] as String)
          : null,
    );
  }
  final int? id;
  final String deviceId;
  final String label;
  final String token;
  final DateTime createdAt;
  final DateTime? lastUsed;

  IntegrationToken copyWith({
    int? id,
    String? deviceId,
    String? label,
    String? token,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return IntegrationToken(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      label: label ?? this.label,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'label': label,
      'token': token,
      'created_at': createdAt.toIso8601String(),
      'last_used': lastUsed?.toIso8601String(),
    };
  }
}
