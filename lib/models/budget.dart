class Budget {
  Budget({
    this.id,
    required this.deviceId,
    required this.month,
    this.fuelLimit = 0,
    this.generalLimit = 0,
    this.householdLimit = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      deviceId: map['device_id'] as String,
      month: map['month'] as String,
      fuelLimit: (map['fuel_limit'] as num?)?.toDouble() ?? 0,
      generalLimit: (map['general_limit'] as num?)?.toDouble() ?? 0,
      householdLimit: (map['household_limit'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
  final int? id;
  final String deviceId;
  final String month; // Format: YYYY-MM
  final double fuelLimit;
  final double generalLimit;
  final double householdLimit;
  final DateTime createdAt;

  double get totalLimit => fuelLimit + generalLimit + householdLimit;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'month': month,
      'fuel_limit': fuelLimit,
      'general_limit': generalLimit,
      'household_limit': householdLimit,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Budget copyWith({
    int? id,
    String? deviceId,
    String? month,
    double? fuelLimit,
    double? generalLimit,
    double? householdLimit,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      month: month ?? this.month,
      fuelLimit: fuelLimit ?? this.fuelLimit,
      generalLimit: generalLimit ?? this.generalLimit,
      householdLimit: householdLimit ?? this.householdLimit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Budget history for vehicles
class BudgetHistory {
  BudgetHistory({
    this.id,
    required this.vehicleId,
    required this.month,
    required this.budgetAmount,
    required this.actualSpent,
    required this.difference,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BudgetHistory.fromMap(Map<String, dynamic> map) {
    return BudgetHistory(
      id: map['id'] as int?,
      vehicleId: map['vehicle_id'] as int,
      month: map['month'] as String,
      budgetAmount: (map['budget_amount'] as num).toDouble(),
      actualSpent: (map['actual_spent'] as num).toDouble(),
      difference: (map['difference'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
  final int? id;
  final int vehicleId;
  final String month; // Format: YYYY-MM
  final double budgetAmount;
  final double actualSpent;
  final double difference; // negative = over budget
  final DateTime createdAt;

  bool get isOverBudget => difference < 0;
  double get percentageSpent =>
      budgetAmount > 0 ? (actualSpent / budgetAmount) * 100 : 0;
  double get percentageDifference =>
      budgetAmount > 0 ? (difference / budgetAmount) * 100 : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'month': month,
      'budget_amount': budgetAmount,
      'actual_spent': actualSpent,
      'difference': difference,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Budget status for current month
class BudgetStatus {
  BudgetStatus({
    required this.vehicleId,
    required this.vehicleName,
    required this.budgetAmount,
    required this.spent,
    required this.remaining,
    required this.percentageUsed,
    required this.daysInMonth,
    required this.daysRemaining,
    required this.dailyBudgetRemaining,
    required this.alertLevel,
    required this.projectedSpending,
    required this.isOnTrack,
  });
  final int vehicleId;
  final String vehicleName;
  final double budgetAmount;
  final double spent;
  final double remaining;
  final double percentageUsed;
  final int daysInMonth;
  final int daysRemaining;
  final double dailyBudgetRemaining;
  final BudgetAlertLevel alertLevel;
  final double projectedSpending;
  final bool isOnTrack;

  bool get isOverBudget => spent > budgetAmount;
  double get overBudgetAmount => spent - budgetAmount;
}

enum BudgetAlertLevel {
  safe, // < 50%
  warning, // 50-75%
  critical, // 75-90%
  exceeded, // 90-100%
  overBudget // > 100%
}

// Spending pace indicator
enum SpendingPace {
  underBudget, // Spending slower than budget pace
  onTrack, // Spending aligned with budget
  tooFast, // Spending faster than budget pace
}

// Family budget summary
class FamilyBudgetSummary {
  FamilyBudgetSummary({
    required this.totalBudget,
    required this.totalSpent,
    required this.totalRemaining,
    required this.percentageUsed,
    required this.vehicleBudgets,
    required this.vehiclesOverBudget,
    required this.vehiclesOnTrack,
    required this.month,
  });
  final double totalBudget;
  final double totalSpent;
  final double totalRemaining;
  final double percentageUsed;
  final List<BudgetStatus> vehicleBudgets;
  final int vehiclesOverBudget;
  final int vehiclesOnTrack;
  final DateTime month;

  bool get isOverBudget => totalSpent > totalBudget;
  double get overBudgetAmount => totalSpent - totalBudget;
}
