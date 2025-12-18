/// Model for expense split information
/// Represents how an expense is divided among family members
class ExpenseSplit {
  ExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.memberId,
    required this.amount,
    required this.splitType,
    this.percentage,
    this.shares,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create ExpenseSplit from database map
  factory ExpenseSplit.fromMap(Map<String, dynamic> map) {
    return ExpenseSplit(
      id: map['id'] as String,
      expenseId: map['expense_id'] as String,
      memberId: map['member_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      splitType: SplitType.values.firstWhere(
        (e) => e.name == map['split_type'],
        orElse: () => SplitType.equal,
      ),
      percentage: map['percentage'] != null
          ? (map['percentage'] as num).toDouble()
          : null,
      shares: map['shares'] as int?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  final String id;
  final String expenseId;
  final int memberId;
  final double amount;
  final SplitType splitType;
  final double? percentage; // For percentage-based splits
  final int? shares; // For share-based splits
  final DateTime createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expense_id': expenseId,
      'member_id': memberId,
      'amount': amount,
      'split_type': splitType.toString().split('.').last,
      'percentage': percentage,
      'shares': shares,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ExpenseSplit copyWith({
    String? id,
    String? expenseId,
    int? memberId,
    double? amount,
    SplitType? splitType,
    double? percentage,
    int? shares,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseSplit(
      id: id ?? this.id,
      expenseId: expenseId ?? this.expenseId,
      memberId: memberId ?? this.memberId,
      amount: amount ?? this.amount,
      splitType: splitType ?? this.splitType,
      percentage: percentage ?? this.percentage,
      shares: shares ?? this.shares,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Types of expense splitting
enum SplitType {
  /// Divide expense equally among all members
  equal,

  /// Custom amounts for each member
  custom,

  /// Split by percentage (e.g., 40%, 30%, 30%)
  percentage,

  /// Split by shares (e.g., 3:2:1)
  shares,

  /// Single person pays (no split)
  single,
}

/// Extension to get display names for split types
extension SplitTypeExtension on SplitType {
  String get displayName {
    switch (this) {
      case SplitType.equal:
        return 'Equal Split';
      case SplitType.custom:
        return 'Custom Split';
      case SplitType.percentage:
        return 'Percentage Split';
      case SplitType.shares:
        return 'Share-based Split';
      case SplitType.single:
        return 'Single Person';
    }
  }

  String get description {
    switch (this) {
      case SplitType.equal:
        return 'Divide equally among selected members';
      case SplitType.custom:
        return 'Manually assign amounts to each member';
      case SplitType.percentage:
        return 'Split by percentage (e.g., 40%-30%-30%)';
      case SplitType.shares:
        return 'Split by shares (e.g., 3:2:1)';
      case SplitType.single:
        return 'Paid by one person only';
    }
  }
}
