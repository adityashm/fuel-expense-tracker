import 'package:flutter/services.dart';

/// Utility class for sanitizing and validating user input
class InputSanitizer {
  // Prevent instantiation
  InputSanitizer._();

  /// Sanitize text input by trimming whitespace and removing special characters if needed
  static String sanitizeText(String input, {bool allowSpecialChars = true}) {
    if (input.isEmpty) return input;

    // Trim leading/trailing whitespace
    String sanitized = input.trim();

    // Remove multiple consecutive spaces
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');

    // If special characters not allowed, remove them
    if (!allowSpecialChars) {
      sanitized = sanitized.replaceAll(RegExp(r'[^\w\s-]'), '');
    }

    return sanitized;
  }

  /// Sanitize vehicle registration number (uppercase, alphanumeric with hyphens)
  static String sanitizeRegistrationNumber(String input) {
    String sanitized = input.trim().toUpperCase();
    // Keep only alphanumeric and hyphens
    sanitized = sanitized.replaceAll(RegExp('[^A-Z0-9-]'), '');
    return sanitized;
  }

  /// Sanitize numeric input (amount, liters, odometer)
  static String sanitizeNumericInput(String input) {
    // Remove all non-numeric characters except decimal point
    return input.replaceAll(RegExp(r'[^\d.]'), '');
  }

  /// Validate and sanitize email
  static String? sanitizeEmail(String? input) {
    if (input == null || input.isEmpty) return null;
    return input.trim().toLowerCase();
  }

  /// Sanitize phone number (digits only)
  static String sanitizePhoneNumber(String input) {
    return input.replaceAll(RegExp(r'[^\d+]'), '');
  }

  /// Sanitize filename (remove path traversal attempts, special chars)
  static String sanitizeFilename(String input) {
    String sanitized = input.trim();
    // Remove path traversal attempts
    sanitized = sanitized.replaceAll(RegExp(r'[./\\]'), '');
    // Remove other special characters except underscore and hyphen
    sanitized = sanitized.replaceAll(RegExp(r'[^\w\s-]'), '');
    // Replace spaces with underscores
    sanitized = sanitized.replaceAll(' ', '_');
    return sanitized;
  }

  /// Sanitize URL (basic validation)
  static String? sanitizeUrl(String? input) {
    if (input == null || input.isEmpty) return null;
    final String sanitized = input.trim();
    // Basic URL validation
    if (!sanitized.startsWith('http://') && !sanitized.startsWith('https://')) {
      return null;
    }
    return sanitized;
  }

  /// Remove HTML tags from input (prevent XSS)
  static String removeHtmlTags(String input) {
    return input.replaceAll(RegExp('<[^>]*>'), '');
  }

  /// Validate string length
  static bool isValidLength(
    String input, {
    int minLength = 0,
    int maxLength = 1000,
  }) {
    final length = input.trim().length;
    return length >= minLength && length <= maxLength;
  }

  /// Check if string contains only allowed characters
  static bool containsOnlyAllowedChars(String input, String pattern) {
    return RegExp(pattern).hasMatch(input);
  }

  /// Create a safe text input formatter that limits length and filters characters
  static List<TextInputFormatter> createSafeTextFormatter({
    int? maxLength,
    bool allowNumbers = true,
    bool allowSpecialChars = true,
  }) {
    final List<TextInputFormatter> formatters = [];

    if (maxLength != null) {
      formatters.add(LengthLimitingTextInputFormatter(maxLength));
    }

    if (!allowNumbers && !allowSpecialChars) {
      formatters.add(FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')));
    } else if (!allowNumbers) {
      formatters
          .add(FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\-_.,!?]')));
    } else if (!allowSpecialChars) {
      formatters
          .add(FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s]')));
    }

    return formatters;
  }

  /// Sanitize description/notes fields
  static String sanitizeDescription(String input, {int maxLength = 500}) {
    String sanitized = input.trim();
    // Remove excessive whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    // Remove HTML tags
    sanitized = removeHtmlTags(sanitized);
    // Limit length
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }
    return sanitized;
  }

  /// Validate Indian vehicle registration format
  static bool isValidIndianRegistration(String regNumber) {
    // Format: AA00AA0000 or AA-00-AA-0000
    final pattern = RegExp(r'^[A-Z]{2}[-]?\d{1,2}[-]?[A-Z]{1,2}[-]?\d{1,4}$');
    return pattern.hasMatch(regNumber.toUpperCase());
  }

  /// Validate positive number
  static bool isPositiveNumber(String input) {
    final number = double.tryParse(input);
    return number != null && number > 0;
  }

  /// Validate number within range
  static bool isInRange(String input, double min, double max) {
    final number = double.tryParse(input);
    return number != null && number >= min && number <= max;
  }

  /// Sanitize amount input (max 2 decimal places)
  static String sanitizeAmount(String input) {
    String sanitized = sanitizeNumericInput(input);

    // Ensure only one decimal point
    final parts = sanitized.split('.');
    if (parts.length > 2) {
      sanitized = '${parts[0]}.${parts.sublist(1).join()}';
    }

    // Limit to 2 decimal places
    if (parts.length == 2 && parts[1].length > 2) {
      sanitized = '${parts[0]}.${parts[1].substring(0, 2)}';
    }

    return sanitized;
  }

  /// Prevent SQL injection in search queries
  static String sanitizeSearchQuery(String query) {
    // Remove SQL keywords and special characters
    String sanitized = query.trim();
    sanitized = sanitized.replaceAll(RegExp(r"['\\]"), '');
    sanitized = sanitized.replaceAll('"', '');
    sanitized = sanitized.replaceAll(
      RegExp(
        r'\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|UNION)\b',
        caseSensitive: false,
      ),
      '',
    );
    return sanitized;
  }

  /// Validate date string is not in future
  static bool isValidDate(DateTime date, {bool allowFuture = false}) {
    if (!allowFuture && date.isAfter(DateTime.now())) {
      return false;
    }
    // Check if date is reasonable (after year 1900)
    if (date.year < 1900) {
      return false;
    }
    return true;
  }

  /// Sanitize user name
  static String sanitizeUserName(String input) {
    String sanitized = input.trim();
    // Remove excessive whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    // Remove leading/trailing special characters
    sanitized = sanitized.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '');
    return sanitized;
  }
}
