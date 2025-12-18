/// Model for payment/settlement transactions
class Payment {
  Payment({
    required this.id,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.paymentDate,
    this.notes,
    this.receiptPath,
    this.referenceNumber,
    this.deviceId,
    required this.createdAt,
    this.updatedAt,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as String,
      fromMemberId: map['from_member_id'] as int,
      toMemberId: map['to_member_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.toString().split('.').last == map['payment_method'],
        orElse: () => PaymentMethod.cash,
      ),
      status: PaymentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => PaymentStatus.pending,
      ),
      paymentDate: DateTime.parse(map['payment_date'] as String),
      notes: map['notes'] as String?,
      receiptPath: map['receipt_path'] as String?,
      referenceNumber: map['reference_number'] as String?,
      deviceId: map['device_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  final String id;
  final int fromMemberId;
  final int toMemberId;
  final double amount;
  final PaymentMethod paymentMethod;
  final PaymentStatus status;
  final DateTime paymentDate;
  final String? notes;
  final String? receiptPath; // Path to payment proof image
  final String? referenceNumber; // UPI transaction ID, etc.
  final String? deviceId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Payment copyWith({
    String? id,
    int? fromMemberId,
    int? toMemberId,
    double? amount,
    PaymentMethod? paymentMethod,
    PaymentStatus? status,
    DateTime? paymentDate,
    String? notes,
    String? receiptPath,
    String? referenceNumber,
    String? deviceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Payment(
      id: id ?? this.id,
      fromMemberId: fromMemberId ?? this.fromMemberId,
      toMemberId: toMemberId ?? this.toMemberId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      paymentDate: paymentDate ?? this.paymentDate,
      notes: notes ?? this.notes,
      receiptPath: receiptPath ?? this.receiptPath,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'from_member_id': fromMemberId,
      'to_member_id': toMemberId,
      'amount': amount,
      'payment_method': paymentMethod.toString().split('.').last,
      'status': status.toString().split('.').last,
      'payment_date': paymentDate.toIso8601String(),
      'notes': notes,
      'receipt_path': receiptPath,
      'reference_number': referenceNumber,
      'device_id': deviceId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Payment methods
enum PaymentMethod {
  cash,
  upi,
  bankTransfer,
  creditCard,
  debitCard,
  other,
}

/// Payment status
enum PaymentStatus {
  pending,
  completed,
  partial,
  failed,
}

/// Extensions for display
extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.debitCard:
        return 'Debit Card';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case PaymentMethod.cash:
        return '💵';
      case PaymentMethod.upi:
        return '📱';
      case PaymentMethod.bankTransfer:
        return '🏦';
      case PaymentMethod.creditCard:
        return '💳';
      case PaymentMethod.debitCard:
        return '💳';
      case PaymentMethod.other:
        return '💰';
    }
  }
}

extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.partial:
        return 'Partial';
      case PaymentStatus.failed:
        return 'Failed';
    }
  }

  String get color {
    switch (this) {
      case PaymentStatus.pending:
        return 'orange';
      case PaymentStatus.completed:
        return 'green';
      case PaymentStatus.partial:
        return 'blue';
      case PaymentStatus.failed:
        return 'red';
    }
  }
}
