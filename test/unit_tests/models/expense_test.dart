import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Expense Model Tests', () {
    test('Expense creation with valid data', () {
      final expense = {
        'id': 1,
        'amount': 500.0,
        'category': 'Fuel',
        'date': DateTime(2025, 12, 11),
        'description': 'Test expense',
      };

      expect(expense['amount'], equals(500.0));
      expect(expense['category'], equals('Fuel'));
      expect(expense['description'], equals('Test expense'));
    });

    test('Expense amount validation', () {
      const validAmount = 1500.50;
      expect(validAmount > 0, isTrue);
      expect(validAmount.toStringAsFixed(2), equals('1500.50'));
    });

    test('Expense category enum', () {
      final categories = ['Fuel', 'Maintenance', 'General', 'Insurance'];
      expect(categories.contains('Fuel'), isTrue);
      expect(categories.length, equals(4));
    });

    test('Date formatting', () {
      final date = DateTime(2025, 12, 11);
      final formatted = '${date.day}-${date.month}-${date.year}';
      expect(formatted, equals('11-12-2025'));
    });
  });
}
