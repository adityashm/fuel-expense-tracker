import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validation Tests', () {
    test('Amount validation - positive number', () {
      bool isValidAmount(double amount) => amount > 0 && amount <= 999999;
      expect(isValidAmount(500), isTrue);
      expect(isValidAmount(-100), isFalse);
      expect(isValidAmount(0), isFalse);
    });

    test('Description validation - not empty', () {
      bool isValidDescription(String desc) =>
          desc.isNotEmpty && desc.length <= 500;
      expect(isValidDescription('Test'), isTrue);
      expect(isValidDescription(''), isFalse);
      expect(isValidDescription('x' * 501), isFalse);
    });

    test('Email validation', () {
      bool isValidEmail(String email) {
        return RegExp(
          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
        ).hasMatch(email);
      }

      expect(isValidEmail('user@example.com'), isTrue);
      expect(isValidEmail('invalid.email'), isFalse);
      expect(isValidEmail('user@'), isFalse);
    });

    test('Phone number validation', () {
      bool isValidPhone(String phone) =>
          RegExp(r'^[+]?[0-9]{6,15}$').hasMatch(phone);
      expect(isValidPhone('9876543210'), isTrue);
      expect(isValidPhone('+919876543210'), isTrue);
      expect(isValidPhone('123'), isFalse);
    });
  });
}
