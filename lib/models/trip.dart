enum TripPurpose {
  personal,
  business,
  commute,
  leisure,
  other,
}

class Trip {
  // True if trip is ongoing

  Trip({
    this.id,
    required this.vehicleId,
    required this.deviceId,
    required this.startLocation,
    this.endLocation,
    this.startOdometer,
    this.endOdometer,
    this.distance,
    required this.startTime,
    this.endTime,
    required this.purpose,
    this.notes,
    this.fuelExpenseId,
    this.isActive = true,
  });

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] as int?,
      vehicleId: map['vehicle_id'] as int? ?? 0,
      deviceId: map['device_id'] as String? ?? '',
      startLocation: map['start_location'] as String? ?? 'Unknown',
      endLocation: map['end_location'] as String?,
      startOdometer: (map['start_odometer'] as num?)?.toDouble(),
      endOdometer: (map['end_odometer'] as num?)?.toDouble(),
      distance: (map['distance'] as num?)?.toDouble(),
      startTime: map['start_time'] != null
          ? DateTime.parse(map['start_time'] as String)
          : DateTime.now(),
      endTime: map['end_time'] != null
          ? DateTime.parse(map['end_time'] as String)
          : null,
      purpose: TripPurpose.values.firstWhere(
        (e) => e.name == map['purpose'],
        orElse: () => TripPurpose.personal,
      ),
      notes: map['notes'] as String?,
      fuelExpenseId: map['fuel_expense_id'] as int?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }
  final int? id;
  final int vehicleId;
  final String deviceId;
  final String startLocation;
  final String? endLocation;
  final double? startOdometer;
  final double? endOdometer;
  final double? distance;
  final DateTime startTime;
  final DateTime? endTime;
  final TripPurpose purpose;
  final String? notes;
  final int? fuelExpenseId; // Link to fuel expense if filled during trip
  final bool isActive;

  // Calculate distance if not provided
  double? get calculatedDistance {
    if (distance != null) return distance;
    if (startOdometer != null && endOdometer != null) {
      return endOdometer! - startOdometer!;
    }
    return null;
  }

  // Calculate duration
  Duration? get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return null;
  }

  // Check if trip is complete
  bool get isComplete => !isActive && endTime != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'device_id': deviceId,
      'start_location': startLocation,
      'end_location': endLocation,
      'start_odometer': startOdometer,
      'end_odometer': endOdometer,
      'distance': distance,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'purpose': purpose.name,
      'notes': notes,
      'fuel_expense_id': fuelExpenseId,
      'is_active': isActive ? 1 : 0,
    };
  }

  Trip copyWith({
    int? id,
    int? vehicleId,
    String? deviceId,
    String? startLocation,
    String? endLocation,
    double? startOdometer,
    double? endOdometer,
    double? distance,
    DateTime? startTime,
    DateTime? endTime,
    TripPurpose? purpose,
    String? notes,
    int? fuelExpenseId,
    bool? isActive,
  }) {
    return Trip(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      deviceId: deviceId ?? this.deviceId,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      startOdometer: startOdometer ?? this.startOdometer,
      endOdometer: endOdometer ?? this.endOdometer,
      distance: distance ?? this.distance,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      purpose: purpose ?? this.purpose,
      notes: notes ?? this.notes,
      fuelExpenseId: fuelExpenseId ?? this.fuelExpenseId,
      isActive: isActive ?? this.isActive,
    );
  }
}
