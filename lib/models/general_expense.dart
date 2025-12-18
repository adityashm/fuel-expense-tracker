import 'dart:convert';

enum ExpenseCategory {
  maintenance,
  insurance,
  parking,
  tolls,
  servicing,
  groceries,
  utilities,
  healthcare,
  education,
  entertainment,
  shopping,
  food,
  transport,
  other,
}

class GeneralExpense {
  GeneralExpense({
    this.id,
    required this.deviceId,
    this.vehicleId,
    required this.date,
    required this.amount,
    required this.category,
    required this.description,
    this.receiptImagePath,
    this.isHouseholdExpense = false,
    this.familyMemberId,
    this.familyMemberName,
    List<int>? splitMemberIds,
    DateTime? createdAt,
  })  : splitMemberIds = List.unmodifiable(splitMemberIds ?? const []),
        createdAt = createdAt ?? DateTime.now();

  factory GeneralExpense.fromMap(Map<String, dynamic> map) {
    List<int> parseSplitIds(raw) {
      if (raw == null || (raw is String && raw.isEmpty)) {
        return const [];
      }
      try {
        final decoded = raw is String ? jsonDecode(raw) : raw;
        if (decoded is List) {
          return decoded
              .whereType<num>()
              .map((value) => value.toInt())
              .toList(growable: false);
        }
      } catch (_) {
        // Ignore malformed payloads
      }
      return const [];
    }

    return GeneralExpense(
      id: map['id'] as int?,
      deviceId: map['device_id'] as String? ?? '',
      vehicleId: map['vehicle_id'] as int?,
      date: map['date'] != null
          ? DateTime.parse(map['date'] as String)
          : DateTime.now(),
      amount: (map['amount'] as num? ?? 0).toDouble(),
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => ExpenseCategory.other,
      ),
      description: map['description'] as String? ?? 'No description',
      receiptImagePath: map['receipt_image_path'] as String?,
      isHouseholdExpense: (map['is_household_expense'] as int? ?? 0) == 1,
      familyMemberId: map['member_id'] as int?,
      familyMemberName: map['member_name'] as String?,
      splitMemberIds: parseSplitIds(map['split_member_ids']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
  final int? id;
  final String deviceId; // Changed from userId to deviceId
  final int? vehicleId; // Nullable for household expenses
  final DateTime date;
  final double amount;
  final ExpenseCategory category;
  final String description;
  final String? receiptImagePath;
  final bool isHouseholdExpense; // New field to distinguish household expenses
  final int? familyMemberId;
  final String? familyMemberName;
  final List<int> splitMemberIds;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    final splitIds = splitMemberIds.isEmpty ? null : jsonEncode(splitMemberIds);
    return {
      'id': id,
      'device_id': deviceId,
      'vehicle_id': vehicleId,
      'date': date.toIso8601String(),
      'amount': amount,
      'category': category.name,
      'description': description,
      'receipt_image_path': receiptImagePath,
      'is_household_expense': isHouseholdExpense ? 1 : 0,
      'member_id': familyMemberId,
      'member_name': familyMemberName,
      'split_member_ids': splitIds,
      'created_at': createdAt.toIso8601String(),
    };
  }

  GeneralExpense copyWith({
    int? id,
    String? deviceId,
    int? vehicleId,
    DateTime? date,
    double? amount,
    ExpenseCategory? category,
    String? description,
    String? receiptImagePath,
    bool? isHouseholdExpense,
    int? familyMemberId,
    String? familyMemberName,
    List<int>? splitMemberIds,
    DateTime? createdAt,
  }) {
    return GeneralExpense(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      isHouseholdExpense: isHouseholdExpense ?? this.isHouseholdExpense,
      familyMemberId: familyMemberId ?? this.familyMemberId,
      familyMemberName: familyMemberName ?? this.familyMemberName,
      splitMemberIds: splitMemberIds ?? this.splitMemberIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
