/// Expense model for tracking expenses
library;

import 'package:flutter/foundation.dart';

@immutable
class Expense {
  const Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.tax,
    required this.date,
    required this.category,
    required this.paymentMethod,
    required this.isPaid,
  });

  /// Create from JSON
  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      tax: (json['tax'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      category: json['category'] as String,
      paymentMethod: json['paymentMethod'] as String,
      isPaid: json['isPaid'] as bool? ?? false,
    );
  }
  final String id;
  final String description;
  final double amount;
  final double tax;
  final DateTime date;
  final String category;
  final String paymentMethod;
  final bool isPaid;

  /// Total amount including tax
  double get total => amount + tax;

  /// Create a copy with updated fields
  Expense copyWith({
    String? id,
    String? description,
    double? amount,
    double? tax,
    DateTime? date,
    String? category,
    String? paymentMethod,
    bool? isPaid,
  }) {
    return Expense(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      tax: tax ?? this.tax,
      date: date ?? this.date,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'tax': tax,
      'date': date.toIso8601String(),
      'category': category,
      'paymentMethod': paymentMethod,
      'isPaid': isPaid,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          description == other.description &&
          amount == other.amount &&
          tax == other.tax &&
          date == other.date &&
          category == other.category &&
          paymentMethod == other.paymentMethod &&
          isPaid == other.isPaid;

  @override
  int get hashCode =>
      id.hashCode ^
      description.hashCode ^
      amount.hashCode ^
      tax.hashCode ^
      date.hashCode ^
      category.hashCode ^
      paymentMethod.hashCode ^
      isPaid.hashCode;

  @override
  String toString() {
    return 'Expense(id: $id, description: $description, amount: $amount, tax: $tax, date: $date, category: $category, paymentMethod: $paymentMethod, isPaid: $isPaid)';
  }
}
