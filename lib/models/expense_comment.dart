enum ExpenseType {
  fuel,
  general,
}

class ExpenseComment {
  ExpenseComment({
    this.id,
    required this.type,
    required this.expenseId,
    required this.deviceId,
    required this.message,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ExpenseComment.fromMap(Map<String, dynamic> map) {
    return ExpenseComment(
      id: map['id'] as int?,
      type: ExpenseType.values.firstWhere(
        (value) => value.name == map['expense_type'],
        orElse: () => ExpenseType.general,
      ),
      expenseId: map['expense_id'] as int,
      deviceId: map['device_id'] as String,
      message: map['message'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
  final int? id;
  final ExpenseType type;
  final int expenseId;
  final String deviceId;
  final String message;
  final DateTime createdAt;

  ExpenseComment copyWith({
    int? id,
    ExpenseType? type,
    int? expenseId,
    String? deviceId,
    String? message,
    DateTime? createdAt,
  }) {
    return ExpenseComment(
      id: id ?? this.id,
      type: type ?? this.type,
      expenseId: expenseId ?? this.expenseId,
      deviceId: deviceId ?? this.deviceId,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expense_type': type.name,
      'expense_id': expenseId,
      'device_id': deviceId,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
