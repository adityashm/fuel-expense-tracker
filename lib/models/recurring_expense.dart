/// Frequency of recurring expenses
enum RecurrenceFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  quarterly,
  yearly,
}

/// Model for recurring household expenses
class RecurringExpense {
  RecurringExpense({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
    this.memberId,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.dayOfMonth,
    this.dayOfWeek,
    required this.isActive,
    this.deviceId,
    required this.createdAt,
    this.updatedAt,
    this.lastGenerated,
    this.nextDue,
  });

  factory RecurringExpense.fromMap(Map<String, dynamic> map) {
    return RecurringExpense(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      memberId: map['member_id'] as int?,
      frequency: RecurrenceFrequency.values.firstWhere(
        (e) => e.toString().split('.').last == map['frequency'],
        orElse: () => RecurrenceFrequency.monthly,
      ),
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      dayOfMonth: map['day_of_month'] as int?,
      dayOfWeek: map['day_of_week'] as int?,
      isActive: (map['is_active'] as int) == 1,
      deviceId: map['device_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      lastGenerated: map['last_generated'] != null
          ? DateTime.parse(map['last_generated'] as String)
          : null,
      nextDue: map['next_due'] != null
          ? DateTime.parse(map['next_due'] as String)
          : null,
    );
  }

  final String id;
  final String title;
  final String description;
  final double amount;
  final String category;
  final int? memberId; // Who typically pays
  final RecurrenceFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final int? dayOfMonth; // For monthly (1-31)
  final int? dayOfWeek; // For weekly (1=Monday, 7=Sunday)
  final bool isActive;
  final String? deviceId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastGenerated; // Last time expense was auto-generated
  final DateTime? nextDue; // Next scheduled date

  RecurringExpense copyWith({
    String? id,
    String? title,
    String? description,
    double? amount,
    String? category,
    int? memberId,
    RecurrenceFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    int? dayOfMonth,
    int? dayOfWeek,
    bool? isActive,
    String? deviceId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastGenerated,
    DateTime? nextDue,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      memberId: memberId ?? this.memberId,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      isActive: isActive ?? this.isActive,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastGenerated: lastGenerated ?? this.lastGenerated,
      nextDue: nextDue ?? this.nextDue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'amount': amount,
      'category': category,
      'member_id': memberId,
      'frequency': frequency.toString().split('.').last,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'day_of_month': dayOfMonth,
      'day_of_week': dayOfWeek,
      'is_active': isActive ? 1 : 0,
      'device_id': deviceId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_generated': lastGenerated?.toIso8601String(),
      'next_due': nextDue?.toIso8601String(),
    };
  }

  /// Calculate next due date based on frequency
  DateTime calculateNextDue() {
    final base = lastGenerated ?? startDate;

    switch (frequency) {
      case RecurrenceFrequency.daily:
        return base.add(const Duration(days: 1));

      case RecurrenceFrequency.weekly:
        return base.add(const Duration(days: 7));

      case RecurrenceFrequency.biweekly:
        return base.add(const Duration(days: 14));

      case RecurrenceFrequency.monthly:
        final day = dayOfMonth ?? base.day;
        var next = DateTime(base.year, base.month + 1, day);
        // Handle case where day doesn't exist in next month (e.g., Feb 31)
        while (next.day != day && next.month != (base.month + 1) % 12) {
          next = DateTime(next.year, next.month, next.day - 1);
        }
        return next;

      case RecurrenceFrequency.quarterly:
        return DateTime(base.year, base.month + 3, base.day);

      case RecurrenceFrequency.yearly:
        return DateTime(base.year + 1, base.month, base.day);
    }
  }

  /// Check if expense is due for generation
  bool isDue() {
    if (!isActive) return false;
    if (endDate != null && DateTime.now().isAfter(endDate!)) return false;

    final next = nextDue ?? calculateNextDue();
    return DateTime.now().isAfter(next) ||
        DateTime.now().isAtSameMomentAs(next);
  }
}

/// Extension for display names
extension RecurrenceFrequencyExtension on RecurrenceFrequency {
  String get displayName {
    switch (this) {
      case RecurrenceFrequency.daily:
        return 'Daily';
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.biweekly:
        return 'Bi-weekly';
      case RecurrenceFrequency.monthly:
        return 'Monthly';
      case RecurrenceFrequency.quarterly:
        return 'Quarterly';
      case RecurrenceFrequency.yearly:
        return 'Yearly';
    }
  }

  String get description {
    switch (this) {
      case RecurrenceFrequency.daily:
        return 'Repeats every day';
      case RecurrenceFrequency.weekly:
        return 'Repeats every week';
      case RecurrenceFrequency.biweekly:
        return 'Repeats every 2 weeks';
      case RecurrenceFrequency.monthly:
        return 'Repeats every month';
      case RecurrenceFrequency.quarterly:
        return 'Repeats every 3 months';
      case RecurrenceFrequency.yearly:
        return 'Repeats every year';
    }
  }
}
