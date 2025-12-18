enum MaintenanceType {
  service,
  repair,
  inspection,
  partReplacement,
  document,
}

class MaintenanceRecord {
  MaintenanceRecord({
    this.id,
    required this.vehicleId,
    required this.deviceId,
    required this.type,
    required this.serviceDate,
    required this.cost,
    this.odometer,
    this.workshop,
    this.notes,
    this.nextDueDate,
    this.documentPath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) {
    return MaintenanceRecord(
      id: map['id'] as int?,
      vehicleId: map['vehicle_id'] as int? ?? 0,
      deviceId: map['device_id'] as String? ?? '',
      type: MaintenanceType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => MaintenanceType.service,
      ),
      serviceDate: map['service_date'] != null
          ? DateTime.parse(map['service_date'] as String)
          : DateTime.now(),
      cost: (map['cost'] as num? ?? 0).toDouble(),
      odometer: (map['odometer'] as num?)?.toDouble(),
      workshop: map['workshop'] as String?,
      notes: map['notes'] as String?,
      nextDueDate: map['next_due_date'] != null
          ? DateTime.parse(map['next_due_date'] as String)
          : null,
      documentPath: map['document_path'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
  final int? id;
  final int vehicleId;
  final String deviceId;
  final MaintenanceType type;
  final DateTime serviceDate;
  final double cost;
  final double? odometer;
  final String? workshop;
  final String? notes;
  final DateTime? nextDueDate;
  final String? documentPath;
  final DateTime createdAt;

  MaintenanceRecord copyWith({
    int? id,
    int? vehicleId,
    String? deviceId,
    MaintenanceType? type,
    DateTime? serviceDate,
    double? cost,
    double? odometer,
    String? workshop,
    String? notes,
    DateTime? nextDueDate,
    String? documentPath,
    DateTime? createdAt,
  }) {
    return MaintenanceRecord(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      deviceId: deviceId ?? this.deviceId,
      type: type ?? this.type,
      serviceDate: serviceDate ?? this.serviceDate,
      cost: cost ?? this.cost,
      odometer: odometer ?? this.odometer,
      workshop: workshop ?? this.workshop,
      notes: notes ?? this.notes,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      documentPath: documentPath ?? this.documentPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'device_id': deviceId,
      'type': type.name,
      'service_date': serviceDate.toIso8601String(),
      'cost': cost,
      'odometer': odometer,
      'workshop': workshop,
      'notes': notes,
      'next_due_date': nextDueDate?.toIso8601String(),
      'document_path': documentPath,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
