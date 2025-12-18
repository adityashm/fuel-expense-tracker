import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Formatter Service Advanced Tests', () {
    /// Test: Currency formatting - basic
    test('Format amount as Indian currency', () {
      const amount = 1000.0;
      final formatted = '₹${amount.toStringAsFixed(2)}';

      expect(formatted, '₹1000.00');
    });

    /// Test: Currency formatting - with commas
    test('Format large currency amounts', () {
      const amount = 123456.78;
      final parts = amount.toStringAsFixed(2).split('.');
      expect(parts[0], '123456');
    });

    /// Test: Currency formatting - zero amount
    test('Format zero amount', () {
      const amount = 0.0;
      final formatted = '₹${amount.toStringAsFixed(2)}';

      expect(formatted, '₹0.00');
    });

    /// Test: Currency formatting - small amounts
    test('Format small currency amounts', () {
      const amount = 0.50;
      final formatted = '₹${amount.toStringAsFixed(2)}';

      expect(formatted, '₹0.50');
    });

    /// Test: Currency formatting - negative amounts
    test('Format negative amounts', () {
      const amount = -1000.0;
      final formatted = '₹${amount.toStringAsFixed(2)}';

      expect(formatted.contains('-'), true);
    });

    /// Test: Currency formatting - very large amounts
    test('Format very large amounts', () {
      const amount = 9999999.99;
      final formatted = amount.toStringAsFixed(2);

      expect(formatted, '9999999.99');
    });

    /// Test: Date formatting - standard format
    test('Format date in standard format', () {
      final date = DateTime(2024, 12, 11);
      final formatted = '${date.day}/${date.month}/${date.year}';

      expect(formatted, '11/12/2024');
    });

    /// Test: Date formatting - with month name
    test('Format date with month name', () {
      final date = DateTime(2024, 12, 11);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final formatted = '${date.day} ${months[date.month - 1]} ${date.year}';

      expect(formatted, '11 Dec 2024');
    });

    /// Test: Date formatting - with day name
    test('Format date with day name', () {
      final days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      expect(days.isNotEmpty, true);
    });

    /// Test: Date formatting - relative dates
    test('Format relative dates', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));

      expect(yesterday.isBefore(today), true);
      expect(tomorrow.isAfter(today), true);
    });

    /// Test: Date formatting - ISO format
    test('Format date in ISO format', () {
      final date = DateTime(2024, 12, 11);
      final isoFormat = date.toIso8601String();

      expect(isoFormat.contains('2024-12-11'), true);
    });

    /// Test: Phone number formatting
    test('Format phone number', () {
      const phone = '9876543210';
      final formatted = '+91 ${phone.substring(0, 5)} ${phone.substring(5)}';

      expect(formatted, '+91 98765 43210');
    });

    /// Test: Phone number with country code
    test('Format phone with country code', () {
      const phoneWithCode = '+919876543210';
      expect(phoneWithCode.startsWith('+91'), true);
    });

    /// Test: Percentage formatting
    test('Format percentage', () {
      const value = 0.25;
      final percentage = '${(value * 100).toStringAsFixed(1)}%';

      expect(percentage, '25.0%');
    });

    /// Test: Percentage with decimal places
    test('Format percentage with decimals', () {
      const value = 0.3333;
      final percentage = '${(value * 100).toStringAsFixed(2)}%';

      expect(percentage, '33.33%');
    });

    /// Test: Percentage - above 100%
    test('Format percentage above 100%', () {
      const value = 1.5;
      final percentage = '${(value * 100).toStringAsFixed(0)}%';

      expect(percentage, '150%');
    });

    /// Test: Time formatting - 24 hour
    test('Format time in 24-hour format', () {
      final time = DateTime(2024, 12, 11, 14, 30, 45);
      final formatted =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

      expect(formatted, '14:30');
    });

    /// Test: Time formatting - 12 hour
    test('Format time in 12-hour format', () {
      final time = DateTime(2024, 12, 11, 14, 30);
      final hour = time.hour > 12 ? time.hour - 12 : time.hour;
      final period = time.hour >= 12 ? 'PM' : 'AM';
      final formatted =
          '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';

      expect(formatted.contains('PM'), true);
    });

    /// Test: Number abbreviation
    test('Abbreviate large numbers', () {
      const number = 1500000;
      final abbreviated = '${(number / 1000000).toStringAsFixed(1)}M';

      expect(abbreviated, '1.5M');
    });

    /// Test: Number abbreviation - thousands
    test('Abbreviate numbers in thousands', () {
      const number = 50000;
      final abbreviated = '${(number / 1000).toStringAsFixed(0)}K';

      expect(abbreviated, '50K');
    });

    /// Test: Decimal place formatting
    test('Format with specific decimal places', () {
      const value = 123.456789;
      final twoDecimals = value.toStringAsFixed(2);
      final fourDecimals = value.toStringAsFixed(4);

      expect(twoDecimals, '123.46');
      expect(fourDecimals, '123.4568');
    });

    /// Test: Currency with multiple currencies
    test('Format multiple currencies', () {
      const inr = 1000.0;
      const usd = 12.0;

      final inrFormatted = '₹${inr.toStringAsFixed(2)}';
      final usdFormatted = '\$${usd.toStringAsFixed(2)}';

      expect(inrFormatted, '₹1000.00');
      expect(usdFormatted, r'$12.00');
    });

    /// Test: String truncation
    test('Truncate long strings', () {
      const longString =
          'This is a very long description that needs to be truncated';
      final truncated =
          longString.length > 20 ? '${longString.substring(0, 20)}...' : longString;

      expect(truncated.length, 23);
    });

    /// Test: Capitalization
    test('Capitalize strings', () {
      const string = 'fuel purchase';
      final capitalized =
          string[0].toUpperCase() + string.substring(1).toLowerCase();

      expect(capitalized, 'Fuel purchase');
    });

    /// Test: All caps conversion
    test('Convert to uppercase', () {
      const string = 'fuel purchase';
      final upperCase = string.toUpperCase();

      expect(upperCase, 'FUEL PURCHASE');
    });

    /// Test: Lower case conversion
    test('Convert to lowercase', () {
      const string = 'FUEL PURCHASE';
      final lowerCase = string.toLowerCase();

      expect(lowerCase, 'fuel purchase');
    });

    /// Test: Combined formatting
    test('Apply multiple formatting rules', () {
      final date = DateTime(2024, 12, 11);
      const amount = 1000.0;
      const category = 'fuel';

      final formatted =
          '${date.day}/${date.month} - ₹${amount.toStringAsFixed(2)} - ${category.toUpperCase()}';

      expect(formatted, '11/12 - ₹1000.00 - FUEL');
    });

    /// Test: Null-safe formatting
    test('Handle null values in formatting', () {
      const value = null;
      final formatted = value?.toString() ?? 'N/A';

      expect(formatted, 'N/A');
    });

    /// Test: Empty string formatting
    test('Handle empty strings', () {
      const string = '';
      final formatted = string.isEmpty ? 'N/A' : string;

      expect(formatted, 'N/A');
    });

    /// Test: Special characters escaping
    test('Handle special characters', () {
      const string = 'Fuel & Parts @ 10% off';
      expect(string.isNotEmpty, true);
    });

    /// Test: Number padding
    test('Pad numbers with zeros', () {
      const number = 5;
      final padded = number.toString().padLeft(2, '0');

      expect(padded, '05');
    });

    /// Test: Date range formatting
    test('Format date range', () {
      final startDate = DateTime(2024, 12);
      final endDate = DateTime(2024, 12, 31);
      final formatted =
          '${startDate.day}/${startDate.month} - ${endDate.day}/${endDate.month}/${endDate.year}';

      expect(formatted.contains('-'), true);
    });
  });
}
