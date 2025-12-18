import 'package:flutter/foundation.dart';

class StringUtils {
  /// Sanitize user input to prevent injection attacks
  static String sanitizeInput(String input) {
    return input
        .trim()
        .replaceAll(RegExp('[<>"\';]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Sanitize for SQL (though we use parameterized queries)
  static String sanitizeForSQL(String input) {
    return input.trim().replaceAll("'", "''").replaceAll('"', '""');
  }

  /// Truncate string to max length
  static String truncate(String text, int maxLength,
      {String ellipsis = '...',}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  /// Capitalize first letter
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1).toLowerCase()}';
  }

  /// Title case
  static String titleCase(String text) {
    return text.split(' ').map((word) => capitalize(word)).join(' ');
  }
}

class RetryHelper {
  /// Retry an operation with exponential backoff
  static Future<T> retryOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 10),
    bool Function(Object error)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration currentDelay = initialDelay;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        if (attempt >= maxRetries) {
          debugPrint('Max retries ($maxRetries) exceeded');
          rethrow;
        }

        if (shouldRetry != null && !shouldRetry(e)) {
          debugPrint('Error not retryable: $e');
          rethrow;
        }

        debugPrint('Retry attempt $attempt after error: $e');
        debugPrint('Waiting ${currentDelay.inSeconds} seconds before retry');

        await Future.delayed(currentDelay);

        // Exponential backoff
        currentDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * 2).clamp(
            initialDelay.inMilliseconds,
            maxDelay.inMilliseconds,
          ),
        );
      }
    }
  }

  /// Retry with custom delay function
  static Future<T> retryWithCustomDelay<T>(
    Future<T> Function() operation, {
    required int maxRetries,
    required Duration Function(int attempt) delayCalculator,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxRetries) {
          rethrow;
        }
        final delay = delayCalculator(attempt);
        debugPrint(
            'Retry attempt $attempt/$maxRetries after ${delay.inSeconds}s',);
        await Future.delayed(delay);
      }
    }
    throw Exception('Should never reach here');
  }
}

class SafeLogger {
  /// Safe debug print that only logs in debug mode
  static void log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Log error with sanitized data
  static void logError(String message,
      [Object? error, StackTrace? stackTrace,]) {
    if (kDebugMode) {
      debugPrint('ERROR: $message');
      if (error != null) {
        debugPrint('Error details: ${_sanitizeError(error)}');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Sanitize error message to remove sensitive data
  static String _sanitizeError(Object error) {
    final errorString = error.toString();
    // Remove potential sensitive patterns (emails, phone numbers, etc.)
    return errorString
        .replaceAll(RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w{2,4}\b'), '[EMAIL]')
        .replaceAll(RegExp(r'\b\d{10,}\b'), '[PHONE]')
        .replaceAll(
            RegExp(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'), '[CARD]',);
  }
}
