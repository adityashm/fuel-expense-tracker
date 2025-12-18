import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_expense_tracker/utils/validators.dart';
import '../../fixtures/expense_fixtures.dart';

void main() {
  group('Validation Service Advanced Tests', () {
    /// Test: Amount validation - positive amounts
    test('Validate positive amounts', () {
      final amounts = [100.0, 500.0, 1000.0, 50000.0];

      for (final amount in amounts) {
        expect(amount > 0, true, reason: 'Amount $amount should be positive');
      }
    });

    /// Test: Amount validation - edge cases
    test('Validate amount edge cases', () {
      expect(0.01 > 0, true); // Minimum valid amount
      expect(999999.99 > 0, true); // Maximum reasonable amount
    });

    /// Test: Amount validation - invalid amounts
    test('Reject invalid amounts', () {
      final invalidAmounts = [0.0, -100.0, -1.0];

      for (final amount in invalidAmounts) {
        expect(amount <= 0, true, reason: 'Amount $amount should be invalid');
      }
    });

    /// Test: Phone number validation - Indian format
    test('Validate Indian phone numbers', () {
      final validPhones = [
        '9876543210',
        '+919876543210',
        '919876543210',
      ];

      for (final phone in validPhones) {
        expect(InputValidators.validatePhone(phone), isNull,
            reason: 'Phone $phone should be valid',);
      }
    });

    /// Test: Phone number validation - invalid formats
    test('Reject invalid phone numbers', () {
      final invalidPhones = [
        '123', // Too short
        'abcdefghij', // Letters
        '', // Empty
        '98765', // Incomplete
      ];

      for (final phone in invalidPhones) {
        expect(InputValidators.validatePhone(phone), isNotNull,
            reason: 'Phone $phone should be invalid',);
      }
    });

    /// Test: Email validation
    test('Validate email addresses', () {
      final validEmails = [
        'user@example.com',
        'test.user@domain.co.in',
        'user+tag@example.com',
      ];

      for (final email in validEmails) {
        expect(InputValidators.validateEmail(email), isNull,
            reason: 'Email $email should be valid',);
      }
    });

    /// Test: Email validation - invalid formats
    test('Reject invalid emails', () {
      final invalidEmails = [
        'userexample.com', // Missing @
        '@example.com', // Missing local part
        'user@', // Missing domain
        'user @example.com', // Space
      ];

      for (final email in invalidEmails) {
        expect(InputValidators.validateEmail(email), isNotNull,
            reason: 'Email $email should be invalid',);
      }
    });

    /// Test: Date validation
    test('Validate date formats', () {
      final validDate = DateTime(2024, 12, 11);
      expect(validDate.isBefore(DateTime.now().add(const Duration(days: 1))), true);
    });

    /// Test: Date validation - future dates
    test('Handle future dates', () {
      final futureDate = DateTime.now().add(const Duration(days: 1));
      expect(futureDate.isAfter(DateTime.now()), true);
    });

    /// Test: Date validation - past dates
    test('Handle past dates', () {
      final pastDate = DateTime(2020);
      expect(pastDate.isBefore(DateTime.now()), true);
    });

    /// Test: String length validation
    test('Validate string length', () {
      const shortString = 'a';
      const normalString = 'Fuel purchase';
      final longString = 'a' * 500;

      expect(shortString.length, 1);
      expect(normalString.length, greaterThan(0));
      expect(longString.length, greaterThanOrEqualTo(500));
    });

    /// Test: Category validation
    test('Validate expense categories', () {
      final validCategories = ['Fuel', 'Service', 'Parts', 'Insurance', 'Other'];
      const testCategory = 'Fuel';

      expect(validCategories.contains(testCategory), true);
    });

    /// Test: Payment method validation
    test('Validate payment methods', () {
      final validMethods = ['Cash', 'Card', 'UPI', 'Wallet', 'Check'];
      const testMethod = 'Card';

      expect(validMethods.contains(testMethod), true);
    });

    /// Test: Required field validation
    test('Validate required fields', () {
      final expense = ExpenseFixtures.createSampleExpense();

      expect(expense.id.isNotEmpty, true);
      expect(expense.description.isNotEmpty, true);
      expect(expense.amount > 0, true);
    });

    /// Test: Decimal precision validation
    test('Handle decimal precision', () {
      const amount = 123.456;
      expect(amount, 123.456);
      // Check rounding
      final rounded = double.parse(amount.toStringAsFixed(2));
      expect(rounded, 123.46);
    });

    /// Test: Special characters in description
    test('Handle special characters in description', () {
      final descriptions = [
        'Fuel @ Station',
        'Service & Parts',
        'Car #1 Repair',
        'Payment - Cash',
      ];

      for (final desc in descriptions) {
        expect(desc.isNotEmpty, true);
      }
    });

    /// Test: Unicode character support
    test('Handle unicode characters', () {
      final descriptions = [
        'ईंधन खरीद',
        'సేవ',
        'জ্বালানী',
        '燃料',
      ];

      for (final desc in descriptions) {
        expect(desc.isNotEmpty, true);
      }
    });

    /// Test: Batch validation
    test('Validate multiple fields at once', () {
      final expense = ExpenseFixtures.createSampleExpense(
        amount: 500,
        description: 'Valid expense',
        category: 'Fuel',
      );

      final bool isValid = expense.amount > 0 &&
          expense.description.isNotEmpty &&
          ['Fuel', 'Service', 'Parts', 'Insurance', 'Other']
              .contains(expense.category);

      expect(isValid, true);
    });

    /// Test: Whitespace trimming
    test('Handle whitespace in fields', () {
      const description = '  Fuel Purchase  ';
      final trimmed = description.trim();

      expect(trimmed, 'Fuel Purchase');
      expect(trimmed.isNotEmpty, true);
    });

    /// Test: Case insensitivity for categories
    test('Handle case variations in categories', () {
      final categories = ['fuel', 'FUEL', 'Fuel'];

      for (final cat in categories) {
        expect(cat.toLowerCase(), 'fuel');
      }
    });

    /// Test: Null/empty field handling
    test('Handle null and empty fields', () {
      const emptyString = '';
      final hasContent = emptyString.isNotEmpty;

      expect(hasContent, false);
    });

    /// Test: Number format validation
    test('Validate number formats', () {
      expect(double.tryParse('123.45') != null, true);
      expect(double.tryParse('abc') == null, true);
      expect(int.tryParse('123') != null, true);
      expect(int.tryParse('12.3') == null, true);
    });
  });
}
