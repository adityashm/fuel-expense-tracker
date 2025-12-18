import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Number Formatting Tests', () {
    test('Currency formatting', () {
      const double amount = 1500.50;
      final String formatted = '₹${amount.toStringAsFixed(2)}';
      expect(formatted, equals('₹1500.50'));
    });

    test('Large amount formatting', () {
      const double amount = 1234567.89;
      final String formatted = '₹${amount.toStringAsFixed(2)}';
      expect(formatted, equals('₹1234567.89'));
    });

    test('Decimal truncation', () {
      const double value = 100.999;
      final String truncated = value.toStringAsFixed(2);
      expect(truncated, equals('101.00'));
    });

    test('Percentage calculation', () {
      const double total = 1000;
      const double spent = 250;
      const double percentage = (spent / total) * 100;
      expect(percentage, equals(25.0));
    });
  });
}
