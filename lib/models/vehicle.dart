enum VehicleType {
  bike,
  car,
  electricBike, // Electric scooters like Ola S1 Pro
  electricCar,
}

class Vehicle {
  Vehicle({
    this.id,
    required this.ownerDeviceId,
    required this.name,
    required this.registrationNumber,
    required this.vehicleType,
    required this.currentOdometer,
    this.isShared = false,
    this.monthlyBudget,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] as int?,
      ownerDeviceId: (map['owner_device_id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Unnamed Vehicle',
      registrationNumber: (map['registration_number'] as String?) ?? 'N/A',
      vehicleType: VehicleType.values.firstWhere(
        (e) => e.name == (map['vehicle_type'] as String?),
        orElse: () => VehicleType.car,
      ),
      currentOdometer: ((map['current_odometer'] as num?) ?? 0).toDouble(),
      isShared: (map['is_shared'] as int?) == 1,
      monthlyBudget: map['monthly_budget'] != null
          ? (map['monthly_budget'] as num).toDouble()
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
  final int? id;
  final String ownerDeviceId;
  final String name;
  final String registrationNumber;
  final VehicleType vehicleType;
  final double currentOdometer;
  final bool isShared;
  final double? monthlyBudget;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_device_id': ownerDeviceId,
      'name': name,
      'registration_number': registrationNumber,
      'vehicle_type': vehicleType.name,
      'current_odometer': currentOdometer,
      'is_shared': isShared ? 1 : 0,
      'monthly_budget': monthlyBudget,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Vehicle copyWith({
    int? id,
    String? ownerDeviceId,
    String? name,
    String? registrationNumber,
    VehicleType? vehicleType,
    double? currentOdometer,
    bool? isShared,
    double? monthlyBudget,
    DateTime? createdAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      ownerDeviceId: ownerDeviceId ?? this.ownerDeviceId,
      name: name ?? this.name,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      currentOdometer: currentOdometer ?? this.currentOdometer,
      isShared: isShared ?? this.isShared,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Check if vehicle is electric
  bool get isElectric =>
      vehicleType == VehicleType.electricBike ||
      vehicleType == VehicleType.electricCar;
}
