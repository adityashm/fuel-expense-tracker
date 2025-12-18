enum SettlementStatus {
  pending,
  settled,
}

class Settlement {
  Settlement({
    this.id,
    required this.vehicleId,
    required this.payerDeviceId,
    required this.payeeDeviceId,
    required this.amount,
    this.status = SettlementStatus.pending,
    DateTime? createdAt,
    this.settledAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Settlement.fromMap(Map<String, dynamic> map) {
    return Settlement(
      id: map['id'] as int?,
      vehicleId: map['vehicle_id'] as int,
      payerDeviceId: map['payer_device_id'] as String,
      payeeDeviceId: map['payee_device_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      status: SettlementStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => SettlementStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      settledAt: map['settled_at'] != null
          ? DateTime.parse(map['settled_at'] as String)
          : null,
    );
  }
  final int? id;
  final int vehicleId;
  final String payerDeviceId;
  final String payeeDeviceId;
  final double amount;
  final SettlementStatus status;
  final DateTime createdAt;
  final DateTime? settledAt;

  Settlement copyWith({
    int? id,
    int? vehicleId,
    String? payerDeviceId,
    String? payeeDeviceId,
    double? amount,
    SettlementStatus? status,
    DateTime? createdAt,
    DateTime? settledAt,
  }) {
    return Settlement(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      payerDeviceId: payerDeviceId ?? this.payerDeviceId,
      payeeDeviceId: payeeDeviceId ?? this.payeeDeviceId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      settledAt: settledAt ?? this.settledAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'payer_device_id': payerDeviceId,
      'payee_device_id': payeeDeviceId,
      'amount': amount,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'settled_at': settledAt?.toIso8601String(),
    };
  }
}
