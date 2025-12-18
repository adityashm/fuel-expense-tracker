import 'charging_expense.dart';
import 'fuel_expense.dart';

enum TemplateType {
  fuel,
  charging,
  general,
}

class ExpenseTemplate {
  ExpenseTemplate({
    this.id,
    required this.name,
    required this.vehicleId,
    required this.vehicleName,
    required this.type,
    this.stationName,
    this.location,
    this.liters,
    this.fuelType,
    this.kwhAmount,
    this.chargingType,
    this.chargingStationName,
    required this.amount,
    this.category,
    this.description,
    this.notes,
    this.useCount = 0,
    this.lastUsedAt,
    DateTime? createdAt,
    this.autoFillOdometer = true,
    this.autoFillDate = true,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ExpenseTemplate.fromMap(Map<String, dynamic> map) {
    return ExpenseTemplate(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'Template',
      vehicleId: map['vehicle_id'] as int? ?? 0,
      vehicleName: map['vehicle_name'] as String? ?? 'Unknown Vehicle',
      type: TemplateType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TemplateType.fuel,
      ),
      stationName: map['station_name'] as String?,
      location: map['location'] as String?,
      liters: (map['liters'] as num?)?.toDouble(),
      fuelType: map['fuel_type'] != null
          ? FuelType.values.firstWhere((e) => e.name == map['fuel_type'],
              orElse: () => FuelType.petrol,)
          : null,
      kwhAmount: (map['kwh_amount'] as num?)?.toDouble(),
      chargingType: map['charging_type'] != null
          ? ChargingType.values.firstWhere(
              (e) => e.name == map['charging_type'],
              orElse: () => ChargingType.slow,)
          : null,
      chargingStationName: map['charging_station_name'] as String?,
      amount: (map['amount'] as num? ?? 0).toDouble(),
      category: map['category'] as String?,
      description: map['description'] as String?,
      notes: map['notes'] as String?,
      useCount: map['use_count'] as int? ?? 0,
      lastUsedAt: map['last_used_at'] != null
          ? DateTime.parse(map['last_used_at'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      autoFillOdometer: (map['auto_fill_odometer'] as int?) == 1,
      autoFillDate: (map['auto_fill_date'] as int?) == 1,
    );
  }
  final int? id;
  final String name;
  final int vehicleId;
  final String vehicleName;
  final TemplateType type;

  // Fuel-specific fields
  final String? stationName;
  final String? location;
  final double? liters;
  final FuelType? fuelType;

  // Charging-specific fields
  final double? kwhAmount;
  final ChargingType? chargingType;
  final String? chargingStationName;

  // General fields
  final double amount;
  final String? category;
  final String? description;
  final String? notes;

  // Analytics
  final int useCount;
  final DateTime? lastUsedAt;
  final DateTime createdAt;

  // Auto-fill preferences
  final bool autoFillOdometer;
  final bool autoFillDate;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'vehicle_id': vehicleId,
      'vehicle_name': vehicleName,
      'type': type.name,
      'station_name': stationName,
      'location': location,
      'liters': liters,
      'fuel_type': fuelType?.name,
      'kwh_amount': kwhAmount,
      'charging_type': chargingType?.name,
      'charging_station_name': chargingStationName,
      'amount': amount,
      'category': category,
      'description': description,
      'notes': notes,
      'use_count': useCount,
      'last_used_at': lastUsedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'auto_fill_odometer': autoFillOdometer ? 1 : 0,
      'auto_fill_date': autoFillDate ? 1 : 0,
    };
  }

  ExpenseTemplate copyWith({
    int? id,
    String? name,
    int? vehicleId,
    String? vehicleName,
    TemplateType? type,
    String? stationName,
    String? location,
    double? liters,
    FuelType? fuelType,
    double? kwhAmount,
    ChargingType? chargingType,
    String? chargingStationName,
    double? amount,
    String? category,
    String? description,
    String? notes,
    int? useCount,
    DateTime? lastUsedAt,
    DateTime? createdAt,
    bool? autoFillOdometer,
    bool? autoFillDate,
  }) {
    return ExpenseTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleName: vehicleName ?? this.vehicleName,
      type: type ?? this.type,
      stationName: stationName ?? this.stationName,
      location: location ?? this.location,
      liters: liters ?? this.liters,
      fuelType: fuelType ?? this.fuelType,
      kwhAmount: kwhAmount ?? this.kwhAmount,
      chargingType: chargingType ?? this.chargingType,
      chargingStationName: chargingStationName ?? this.chargingStationName,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      useCount: useCount ?? this.useCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
      autoFillOdometer: autoFillOdometer ?? this.autoFillOdometer,
      autoFillDate: autoFillDate ?? this.autoFillDate,
    );
  }

  String getSummary() {
    switch (type) {
      case TemplateType.fuel:
        return '${liters?.toStringAsFixed(1)}L at ${stationName ?? "Station"}';
      case TemplateType.charging:
        return '${kwhAmount?.toStringAsFixed(1)} kWh ${chargingType == ChargingType.slow ? "Home" : chargingStationName ?? "Public"}';
      case TemplateType.general:
        return description ?? category ?? 'General expense';
    }
  }
}

class FavoriteStation {
  FavoriteStation({
    this.id,
    required this.name,
    this.address,
    this.location,
    this.lastPricePerLiter,
    this.lastPriceUpdatedAt,
    this.useCount = 0,
    this.lastUsedAt,
    DateTime? createdAt,
    this.brand,
    List<String>? fuelTypes,
    this.hasAirPump = false,
    this.hasWashingFacility = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        fuelTypes = fuelTypes ?? [];

  factory FavoriteStation.fromMap(Map<String, dynamic> map) {
    return FavoriteStation(
      id: map['id'] as int?,
      name: map['name'] as String,
      address: map['address'] as String?,
      location: map['location'] as String?,
      lastPricePerLiter: map['last_price_per_liter'] as double?,
      lastPriceUpdatedAt: map['last_price_updated_at'] != null
          ? DateTime.parse(map['last_price_updated_at'] as String)
          : null,
      useCount: map['use_count'] as int? ?? 0,
      lastUsedAt: map['last_used_at'] != null
          ? DateTime.parse(map['last_used_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      brand: map['brand'] as String?,
      fuelTypes: map['fuel_types'] != null
          ? (map['fuel_types'] as String)
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList()
          : [],
      hasAirPump: (map['has_air_pump'] as int?) == 1,
      hasWashingFacility: (map['has_washing_facility'] as int?) == 1,
    );
  }
  final int? id;
  final String name;
  final String? address;
  final String? location; // Lat,Long
  final double? lastPricePerLiter;
  final DateTime? lastPriceUpdatedAt;
  final int useCount;
  final DateTime? lastUsedAt;
  final DateTime createdAt;

  // Station metadata
  final String? brand; // HP, Shell, IOCL, etc.
  final List<String> fuelTypes; // petrol, diesel, CNG
  final bool hasAirPump;
  final bool hasWashingFacility;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'location': location,
      'last_price_per_liter': lastPricePerLiter,
      'last_price_updated_at': lastPriceUpdatedAt?.toIso8601String(),
      'use_count': useCount,
      'last_used_at': lastUsedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'brand': brand,
      'fuel_types': fuelTypes.join(','),
      'has_air_pump': hasAirPump ? 1 : 0,
      'has_washing_facility': hasWashingFacility ? 1 : 0,
    };
  }

  // Helper getters for geofencing
  String get stationName => name;

  double? get latitude {
    if (location == null) return null;
    final parts = location!.split(',');
    if (parts.length != 2) return null;
    return double.tryParse(parts[0].trim());
  }

  double? get longitude {
    if (location == null) return null;
    final parts = location!.split(',');
    if (parts.length != 2) return null;
    return double.tryParse(parts[1].trim());
  }

  FavoriteStation copyWith({
    int? id,
    String? name,
    String? address,
    String? location,
    double? lastPricePerLiter,
    DateTime? lastPriceUpdatedAt,
    int? useCount,
    DateTime? lastUsedAt,
    DateTime? createdAt,
    String? brand,
    List<String>? fuelTypes,
    bool? hasAirPump,
    bool? hasWashingFacility,
  }) {
    return FavoriteStation(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      location: location ?? this.location,
      lastPricePerLiter: lastPricePerLiter ?? this.lastPricePerLiter,
      lastPriceUpdatedAt: lastPriceUpdatedAt ?? this.lastPriceUpdatedAt,
      useCount: useCount ?? this.useCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
      brand: brand ?? this.brand,
      fuelTypes: fuelTypes ?? this.fuelTypes,
      hasAirPump: hasAirPump ?? this.hasAirPump,
      hasWashingFacility: hasWashingFacility ?? this.hasWashingFacility,
    );
  }

  String getPriceInfo() {
    if (lastPricePerLiter != null && lastPriceUpdatedAt != null) {
      final daysAgo = DateTime.now().difference(lastPriceUpdatedAt!).inDays;
      if (daysAgo == 0) {
        return '₹${lastPricePerLiter!.toStringAsFixed(2)}/L (today)';
      } else if (daysAgo == 1) {
        return '₹${lastPricePerLiter!.toStringAsFixed(2)}/L (yesterday)';
      } else {
        return '₹${lastPricePerLiter!.toStringAsFixed(2)}/L ($daysAgo days ago)';
      }
    }
    return 'No price info';
  }
}

class RecentExpenseQuickFill {
  RecentExpenseQuickFill({
    required this.amount,
    this.quantity,
    this.stationName,
    required this.date,
  }) : daysAgo = DateTime.now().difference(date).inDays;
  final double amount;
  final double? quantity;
  final String? stationName;
  final DateTime date;
  final int daysAgo;

  String getDisplayText() {
    final quantityText =
        quantity != null ? ' (${quantity!.toStringAsFixed(1)}L)' : '';
    if (daysAgo == 0) {
      return '₹${amount.toStringAsFixed(0)}$quantityText - Today';
    } else if (daysAgo == 1) {
      return '₹${amount.toStringAsFixed(0)}$quantityText - Yesterday';
    } else {
      return '₹${amount.toStringAsFixed(0)}$quantityText - $daysAgo days ago';
    }
  }
}

class TemplateSuggestion {
  // "You usually fill on Monday mornings"

  TemplateSuggestion({
    required this.template,
    required this.reason,
    required this.confidence,
    required this.timeContext,
  });
  final ExpenseTemplate template;
  final String reason;
  final double confidence; // 0.0 to 1.0
  final String timeContext;
}
