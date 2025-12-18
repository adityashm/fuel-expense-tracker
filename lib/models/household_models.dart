/// Recurring expense model for bills that repeat on a schedule
class RecurringExpense {
  RecurringExpense({
    required this.id,
    required this.householdId,
    required this.description,
    required this.amount,
    required this.category,
    required this.frequency,
    this.customDays,
    required this.startDate,
    this.endDate,
    this.createdByMembers,
    this.splitPercentages,
    this.autoSplit = true,
    this.generatedDates,
    this.lastGeneratedDate,
    required this.createdAt,
    this.updatedAt,
  });

  factory RecurringExpense.fromJson(Map<String, dynamic> json) {
    return RecurringExpense(
      id: json['id'] as String,
      householdId: json['householdId'] as int,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      frequency: json['frequency'] as String,
      customDays: json['customDays'] as int?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      createdByMembers: List<int>.from(json['createdByMembers'] as List? ?? []),
      splitPercentages:
          Map<String, double>.from(json['splitPercentages'] as Map? ?? {}),
      autoSplit: json['autoSplit'] as bool? ?? true,
      generatedDates: (json['generatedDates'] as List?)
          ?.map((d) => DateTime.parse(d as String))
          .toList(),
      lastGeneratedDate: json['lastGeneratedDate'] != null
          ? DateTime.parse(json['lastGeneratedDate'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
  final String id;
  final int householdId;
  final String description;
  final double amount;
  final String category;
  final String frequency; // daily, weekly, monthly, yearly, custom
  final int? customDays; // For custom frequency (every N days)
  final DateTime startDate;
  final DateTime? endDate;
  final List<int>? createdByMembers; // Member IDs who contribute
  final Map<String, double>? splitPercentages; // Member splits
  final bool autoSplit; // Auto-split among members
  final List<DateTime>? generatedDates; // Already generated dates
  final DateTime? lastGeneratedDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'householdId': householdId,
      'description': description,
      'amount': amount,
      'category': category,
      'frequency': frequency,
      'customDays': customDays,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'createdByMembers': createdByMembers,
      'splitPercentages': splitPercentages,
      'autoSplit': autoSplit,
      'generatedDates':
          generatedDates?.map((d) => d.toIso8601String()).toList(),
      'lastGeneratedDate': lastGeneratedDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  RecurringExpense copyWith({
    String? id,
    int? householdId,
    String? description,
    double? amount,
    String? category,
    String? frequency,
    int? customDays,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? createdByMembers,
    Map<String, double>? splitPercentages,
    bool? autoSplit,
    List<DateTime>? generatedDates,
    DateTime? lastGeneratedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      customDays: customDays ?? this.customDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdByMembers: createdByMembers ?? this.createdByMembers,
      splitPercentages: splitPercentages ?? this.splitPercentages,
      autoSplit: autoSplit ?? this.autoSplit,
      generatedDates: generatedDates ?? this.generatedDates,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'RecurringExpense(id: $id, desc: $description, amount: $amount)';
}

/// Budget tracking model for categories and members
class Budget {
  Budget({
    required this.id,
    required this.householdId,
    required this.name,
    this.category,
    this.memberId,
    required this.limitAmount,
    required this.month,
    required this.year,
    this.currentSpent = 0.0,
    required this.createdAt,
    this.updatedAt,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      householdId: json['householdId'] as int,
      name: json['name'] as String,
      category: json['category'] as String?,
      memberId: json['memberId'] as int?,
      limitAmount: (json['limitAmount'] as num).toDouble(),
      month: json['month'] as int,
      year: json['year'] as int,
      currentSpent: (json['currentSpent'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
  final String id;
  final int householdId;
  final String name;
  final String? category; // Null = family budget, otherwise category-specific
  final int? memberId; // Null = family budget, otherwise member-specific
  final double limitAmount;
  final int month; // 1-12
  final int year;
  final double currentSpent;
  final DateTime createdAt;
  final DateTime? updatedAt;

  double get remainingBudget => limitAmount - currentSpent;
  double get percentageUsed => currentSpent / limitAmount;
  bool get isExceeded => currentSpent > limitAmount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'householdId': householdId,
      'name': name,
      'category': category,
      'memberId': memberId,
      'limitAmount': limitAmount,
      'month': month,
      'year': year,
      'currentSpent': currentSpent,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  Budget copyWith({
    String? id,
    int? householdId,
    String? name,
    String? category,
    int? memberId,
    double? limitAmount,
    int? month,
    int? year,
    double? currentSpent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      category: category ?? this.category,
      memberId: memberId ?? this.memberId,
      limitAmount: limitAmount ?? this.limitAmount,
      month: month ?? this.month,
      year: year ?? this.year,
      currentSpent: currentSpent ?? this.currentSpent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'Budget(id: $id, name: $name, limit: $limitAmount, spent: $currentSpent)';
}

/// Financial goal model
class FinancialGoal {
  FinancialGoal({
    required this.id,
    required this.householdId,
    required this.name,
    required this.description,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.startDate,
    this.targetDate,
    required this.category,
    this.completed = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory FinancialGoal.fromJson(Map<String, dynamic> json) {
    return FinancialGoal(
      id: json['id'] as String,
      householdId: json['householdId'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0.0,
      startDate: DateTime.parse(json['startDate'] as String),
      targetDate: json['targetDate'] != null
          ? DateTime.parse(json['targetDate'] as String)
          : null,
      category: json['category'] as String,
      completed: json['completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
  final String id;
  final int householdId;
  final String name;
  final String description;
  final double targetAmount;
  final double currentAmount;
  final DateTime startDate;
  final DateTime? targetDate;
  final String category; // savings, reduce-spending, etc
  final bool completed;
  final DateTime createdAt;
  final DateTime? updatedAt;

  double get progressPercentage => currentAmount / targetAmount;
  double get remainingAmount => targetAmount - currentAmount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'householdId': householdId,
      'name': name,
      'description': description,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'startDate': startDate.toIso8601String(),
      'targetDate': targetDate?.toIso8601String(),
      'category': category,
      'completed': completed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  FinancialGoal copyWith({
    String? id,
    int? householdId,
    String? name,
    String? description,
    double? targetAmount,
    double? currentAmount,
    DateTime? startDate,
    DateTime? targetDate,
    String? category,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinancialGoal(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      category: category ?? this.category,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'FinancialGoal(id: $id, name: $name, target: $targetAmount)';
}
