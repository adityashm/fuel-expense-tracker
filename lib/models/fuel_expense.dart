import 'dart:convert';

enum FuelType {
  petrol,
  diesel,
  cng,
}

class FuelExpense {
  FuelExpense({
    this.id,
    required this.deviceId,
    required this.vehicleId,
    required this.date,
    required this.fuelType,
    required this.amountPaid,
    required this.liters,
    required this.odometerReading,
    this.pumpName,
    this.location,
    this.receiptImagePath,
    this.notes,
    this.familyMemberId,
    this.familyMemberName,
    List<int>? splitMemberIds,
    DateTime? createdAt,
    this.isFullTank = false,
    this.fuelEfficiency,
    this.costPerLiter,
  })  : splitMemberIds = List.unmodifiable(splitMemberIds ?? const []),
        createdAt = createdAt ?? DateTime.now();

  factory FuelExpense.fromMap(Map<String, dynamic> map) {
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

    return FuelExpense(
      id: map['id'] as int?,
      deviceId: map['device_id'] as String? ?? '',
      vehicleId: map['vehicle_id'] as int? ?? 0,
      date: map['date'] != null
          ? DateTime.parse(map['date'] as String)
          : DateTime.now(),
      fuelType: FuelType.values.firstWhere(
        (e) => e.name == map['fuel_type'],
        orElse: () => FuelType.petrol,
      ),
      amountPaid: (map['amount_paid'] as num? ?? 0).toDouble(),
      liters: (map['liters'] as num? ?? 0).toDouble(),
      odometerReading: (map['odometer_reading'] as num? ?? 0).toDouble(),
      pumpName: map['pump_name'] as String?,
      location: map['location'] as String?,
      receiptImagePath: map['receipt_image_path'] as String?,
      notes: map['notes'] as String?,
      familyMemberId: map['member_id'] as int?,
      familyMemberName: map['member_name'] as String?,
      splitMemberIds: parseSplitIds(map['split_member_ids']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      isFullTank: (map['is_full_tank'] as int? ?? 0) == 1,
      fuelEfficiency: (map['fuel_efficiency'] as num?)?.toDouble(),
      costPerLiter: (map['cost_per_liter'] as num?)?.toDouble(),
    );
  }
  final int? id;
  final String deviceId;
  final int vehicleId;
  final DateTime date;
  final FuelType fuelType;
  final double amountPaid;
  final double liters;
  final double odometerReading;
  final String? pumpName;
  final String? location;
  final String? receiptImagePath;
  final String? notes;
  final int? familyMemberId;
  final String? familyMemberName;
  final List<int> splitMemberIds;
  final DateTime createdAt;
  final bool isFullTank;
  final double? fuelEfficiency;
  final double? costPerLiter;

  Map<String, dynamic> toMap() {
    final splitIds = splitMemberIds.isEmpty ? null : jsonEncode(splitMemberIds);
    return {
      'id': id,
      'device_id': deviceId,
      'vehicle_id': vehicleId,
      'date': date.toIso8601String(),
      'fuel_type': fuelType.name,
      'amount_paid': amountPaid,
      'liters': liters,
      'odometer_reading': odometerReading,
      'pump_name': pumpName,
      'location': location,
      'receipt_image_path': receiptImagePath,
      'notes': notes,
      'member_id': familyMemberId,
      'member_name': familyMemberName,
      'split_member_ids': splitIds,
      'created_at': createdAt.toIso8601String(),
      'is_full_tank': isFullTank ? 1 : 0,
      'fuel_efficiency': fuelEfficiency,
      'cost_per_liter': costPerLiter,
    };
  }

  FuelExpense copyWith({
    int? id,
    String? deviceId,
    int? vehicleId,
    DateTime? date,
    FuelType? fuelType,
    double? amountPaid,
    double? liters,
    double? odometerReading,
    String? pumpName,
    String? location,
    String? receiptImagePath,
    String? notes,
    int? familyMemberId,
    String? familyMemberName,
    List<int>? splitMemberIds,
    DateTime? createdAt,
    bool? isFullTank,
    double? fuelEfficiency,
    double? costPerLiter,
  }) {
    return FuelExpense(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      fuelType: fuelType ?? this.fuelType,
      amountPaid: amountPaid ?? this.amountPaid,
      liters: liters ?? this.liters,
      odometerReading: odometerReading ?? this.odometerReading,
      pumpName: pumpName ?? this.pumpName,
      location: location ?? this.location,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      notes: notes ?? this.notes,
      familyMemberId: familyMemberId ?? this.familyMemberId,
      familyMemberName: familyMemberName ?? this.familyMemberName,
      splitMemberIds: splitMemberIds ?? this.splitMemberIds,
      createdAt: createdAt ?? this.createdAt,
      isFullTank: isFullTank ?? this.isFullTank,
      fuelEfficiency: fuelEfficiency ?? this.fuelEfficiency,
      costPerLiter: costPerLiter ?? this.costPerLiter,
    );
  }
}
