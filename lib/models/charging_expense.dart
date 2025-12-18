enum ChargingLocationType {
  home,
  publicStation,
  office,
  other,
}

enum ChargingType {
  slow, // < 3 kW
  fast, // 3-7 kW
  rapid, // > 7 kW
}

class ChargingExpense {
  ChargingExpense({
    this.id,
    required this.deviceId,
    required this.vehicleId,
    required this.date,
    required this.locationType,
    required this.kwhCharged,
    required this.costPerUnit,
    required this.totalCost,
    required this.batteryBefore,
    required this.batteryAfter,
    required this.durationMinutes,
    required this.odometerReading,
    required this.chargingType,
    this.stationName,
    this.address,
    this.notes,
    this.familyMemberId,
    this.familyMemberName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ChargingExpense.fromMap(Map<String, dynamic> map) {
    return ChargingExpense(
      id: map['id'] as int?,
      deviceId: map['device_id'] as String? ?? '',
      vehicleId: map['vehicle_id'] as int? ?? 0,
      date: map['date'] != null
          ? DateTime.parse(map['date'] as String)
          : DateTime.now(),
      locationType: ChargingLocationType.values.firstWhere(
        (e) => e.name == map['location_type'],
        orElse: () => ChargingLocationType.other,
      ),
      kwhCharged: (map['kwh_charged'] as num? ?? 0).toDouble(),
      costPerUnit: (map['cost_per_unit'] as num? ?? 0).toDouble(),
      totalCost: (map['total_cost'] as num? ?? 0).toDouble(),
      batteryBefore: map['battery_before'] as int? ?? 0,
      batteryAfter: map['battery_after'] as int? ?? 0,
      durationMinutes: map['duration_minutes'] as int? ?? 0,
      odometerReading: (map['odometer_reading'] as num? ?? 0).toDouble(),
      chargingType: ChargingType.values.firstWhere(
        (e) => e.name == map['charging_type'],
        orElse: () => ChargingType.slow,
      ),
      stationName: map['station_name'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      familyMemberId: map['member_id'] as int?,
      familyMemberName: map['member_name'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
  final int? id;
  final String deviceId;
  final int vehicleId;
  final DateTime date;
  final ChargingLocationType locationType;
  final double kwhCharged; // Units consumed
  final double costPerUnit; // ₹/kWh
  final double totalCost; // Total amount paid
  final int batteryBefore; // Percentage (0-100)
  final int batteryAfter; // Percentage (0-100)
  final int durationMinutes; // Charging duration
  final double odometerReading; // km
  final ChargingType chargingType;
  final String? stationName; // Name of charging station (for public/office)
  final String? address; // Location address
  final String? notes;
  final int? familyMemberId;
  final String? familyMemberName;
  final DateTime createdAt;

  // Calculated metrics
  int get batteryGained => batteryAfter - batteryBefore;

  double get costPerPercent =>
      batteryGained > 0 ? totalCost / batteryGained : 0;

  double get kwhPerPercent =>
      batteryGained > 0 ? kwhCharged / batteryGained : 0;

  double get averageChargingPower =>
      durationMinutes > 0 ? (kwhCharged * 60) / durationMinutes : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'vehicle_id': vehicleId,
      'date': date.toIso8601String(),
      'location_type': locationType.name,
      'kwh_charged': kwhCharged,
      'cost_per_unit': costPerUnit,
      'total_cost': totalCost,
      'battery_before': batteryBefore,
      'battery_after': batteryAfter,
      'duration_minutes': durationMinutes,
      'odometer_reading': odometerReading,
      'charging_type': chargingType.name,
      'station_name': stationName,
      'address': address,
      'notes': notes,
      'member_id': familyMemberId,
      'member_name': familyMemberName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ChargingExpense copyWith({
    int? id,
    String? deviceId,
    int? vehicleId,
    DateTime? date,
    ChargingLocationType? locationType,
    double? kwhCharged,
    double? costPerUnit,
    double? totalCost,
    int? batteryBefore,
    int? batteryAfter,
    int? durationMinutes,
    double? odometerReading,
    ChargingType? chargingType,
    String? stationName,
    String? address,
    String? notes,
    int? familyMemberId,
    String? familyMemberName,
    DateTime? createdAt,
  }) {
    return ChargingExpense(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      locationType: locationType ?? this.locationType,
      kwhCharged: kwhCharged ?? this.kwhCharged,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      totalCost: totalCost ?? this.totalCost,
      batteryBefore: batteryBefore ?? this.batteryBefore,
      batteryAfter: batteryAfter ?? this.batteryAfter,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      odometerReading: odometerReading ?? this.odometerReading,
      chargingType: chargingType ?? this.chargingType,
      stationName: stationName ?? this.stationName,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      familyMemberId: familyMemberId ?? this.familyMemberId,
      familyMemberName: familyMemberName ?? this.familyMemberName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// EV Efficiency Metrics
class EVEfficiencyMetrics {
  EVEfficiencyMetrics({
    required this.totalKwhCharged,
    required this.totalCost,
    required this.totalKmDriven,
    required this.chargingCycles,
    required this.homeChargingCost,
    required this.publicChargingCost,
    required this.averageCostPerKwh,
    required this.periodStart,
    required this.periodEnd,
  });
  final double totalKwhCharged;
  final double totalCost;
  final double totalKmDriven;
  final int chargingCycles;
  final double homeChargingCost;
  final double publicChargingCost;
  final double averageCostPerKwh;
  final DateTime periodStart;
  final DateTime periodEnd;

  // kWh per 100 km
  double get kwhPer100Km =>
      totalKmDriven > 0 ? (totalKwhCharged / totalKmDriven) * 100 : 0;

  // Cost per km in ₹
  double get costPerKm => totalKmDriven > 0 ? totalCost / totalKmDriven : 0;

  // Average cost per charging session
  double get averageCostPerSession =>
      chargingCycles > 0 ? totalCost / chargingCycles : 0;

  // Home vs public cost ratio
  double get homeToPublicCostRatio =>
      publicChargingCost > 0 ? homeChargingCost / publicChargingCost : 0;

  // Savings percentage vs public charging (if all was public)
  double get homeChargingSavingsPercent {
    if (totalCost <= 0) return 0;
    final potentialPublicCost =
        homeChargingCost * 2.5; // Assume public is 2.5x home cost
    return ((potentialPublicCost - homeChargingCost) / potentialPublicCost) *
        100;
  }
}

// Petrol comparison data
class EVVsPetrolComparison {
  EVVsPetrolComparison({
    required this.evCostPerKm,
    required this.petrolCostPerKm,
    required this.monthlySavings,
    required this.co2Saved,
    required this.totalEvCost,
    required this.equivalentPetrolCost,
  });
  final double evCostPerKm;
  final double petrolCostPerKm;
  final double monthlySavings;
  final double co2Saved; // kg CO2
  final double totalEvCost;
  final double equivalentPetrolCost;

  double get savingsPercent => equivalentPetrolCost > 0
      ? ((equivalentPetrolCost - totalEvCost) / equivalentPetrolCost) * 100
      : 0;
}

// Battery health tracking
class BatteryHealthData {
  BatteryHealthData({
    required this.totalChargingCycles,
    required this.fastChargingCycles,
    required this.slowChargingCycles,
    required this.averageBatteryGainPerCycle,
    required this.estimatedHealthPercent,
    required this.firstChargeDate,
    required this.lastChargeDate,
  });
  final int totalChargingCycles;
  final int fastChargingCycles;
  final int slowChargingCycles;
  final double averageBatteryGainPerCycle;
  final double estimatedHealthPercent;
  final DateTime firstChargeDate;
  final DateTime lastChargeDate;

  int get daysInUse => lastChargeDate.difference(firstChargeDate).inDays;

  double get averageCyclesPerMonth =>
      daysInUse > 0 ? (totalChargingCycles / daysInUse) * 30 : 0;

  // Fast charging percentage (higher = more stress on battery)
  double get fastChargingPercent => totalChargingCycles > 0
      ? (fastChargingCycles / totalChargingCycles) * 100
      : 0;
}
