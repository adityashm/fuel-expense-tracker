class User {
  User({
    this.id,
    required this.name,
    this.profilePicturePath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      name: map['name'] as String,
      profilePicturePath: map['profile_picture_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
  final int? id;
  final String name;
  final String? profilePicturePath;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'profile_picture_path': profilePicturePath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? profilePicturePath,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      profilePicturePath: profilePicturePath ?? this.profilePicturePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
