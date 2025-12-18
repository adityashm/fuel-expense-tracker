/// Model for tracking allowances given to family members (e.g., from father)
/// and how much has been spent from that allowance
class Allowance {
  Allowance({
    this.id,
    required this.memberId,
    required this.givenBy,
    required this.amount,
    required this.givenDate,
    this.purpose,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Allowance.fromMap(Map<String, dynamic> map) {
    return Allowance(
      id: map['id'] as int?,
      memberId: map['member_id'] as int,
      givenBy: map['given_by'] as String,
      amount: (map['amount'] as num).toDouble(),
      givenDate: DateTime.parse(map['given_date'] as String),
      purpose: map['purpose'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  final int? id;
  final int memberId; // which family member received this
  final String givenBy; // who gave it (e.g., "Father", "Mother")
  final double amount; // amount given
  final DateTime givenDate; // when it was given
  final String?
      purpose; // optional purpose (e.g., "Monthly allowance", "School expenses")
  final String? notes;
  final DateTime createdAt;

  Allowance copyWith({
    int? id,
    int? memberId,
    String? givenBy,
    double? amount,
    DateTime? givenDate,
    String? purpose,
    String? notes,
    DateTime? createdAt,
  }) {
    return Allowance(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      givenBy: givenBy ?? this.givenBy,
      amount: amount ?? this.amount,
      givenDate: givenDate ?? this.givenDate,
      purpose: purpose ?? this.purpose,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'member_id': memberId,
      'given_by': givenBy,
      'amount': amount,
      'given_date': givenDate.toIso8601String(),
      'purpose': purpose,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
