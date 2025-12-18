class CommunityPost {
  CommunityPost({
    this.id,
    required this.deviceId,
    required this.authorName,
    required this.title,
    required this.message,
    this.location,
    this.fuelPrice,
    this.likes = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CommunityPost.fromMap(Map<String, dynamic> map) {
    return CommunityPost(
      id: map['id'] as int?,
      deviceId: map['device_id'] as String,
      authorName: map['author_name'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      location: map['location'] as String?,
      fuelPrice: (map['fuel_price'] as num?)?.toDouble(),
      likes: (map['likes'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
  final int? id;
  final String deviceId;
  final String authorName;
  final String title;
  final String message;
  final String? location;
  final double? fuelPrice;
  final int likes;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'author_name': authorName,
      'title': title,
      'message': message,
      'location': location,
      'fuel_price': fuelPrice,
      'likes': likes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CommunityPost copyWith({
    int? id,
    String? deviceId,
    String? authorName,
    String? title,
    String? message,
    String? location,
    double? fuelPrice,
    int? likes,
    DateTime? createdAt,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      authorName: authorName ?? this.authorName,
      title: title ?? this.title,
      message: message ?? this.message,
      location: location ?? this.location,
      fuelPrice: fuelPrice ?? this.fuelPrice,
      likes: likes ?? this.likes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
