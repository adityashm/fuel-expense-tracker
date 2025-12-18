/// Custom exception types for better error handling
library;

class GeofenceException implements Exception {
  const GeofenceException(this.message, [this.originalError]);
  final String message;
  final dynamic originalError;

  @override
  String toString() => 'GeofenceException: $message';
}

class LocationPermissionException extends GeofenceException {
  const LocationPermissionException([String? message])
      : super(message ?? 'Location permission denied');
}

class LocationServiceException extends GeofenceException {
  const LocationServiceException([String? message])
      : super(message ?? 'Location services disabled');
}

class DatabaseException implements Exception {
  const DatabaseException(this.message, [this.originalError]);
  final String message;
  final dynamic originalError;

  @override
  String toString() => 'DatabaseException: $message';
}

class NetworkException implements Exception {
  const NetworkException(this.message, {this.statusCode, this.originalError});
  final String message;
  final int? statusCode;
  final dynamic originalError;

  @override
  String toString() =>
      'NetworkException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

class SyncException implements Exception {
  const SyncException(this.message, [this.originalError]);
  final String message;
  final dynamic originalError;

  @override
  String toString() => 'SyncException: $message';
}

/// Retry utility with exponential backoff
class RetryHelper {
  /// Retry a function with exponential backoff
  ///
  /// [action] - The function to retry
  /// [maxAttempts] - Maximum number of retry attempts (default: 3)
  /// [initialDelay] - Initial delay before first retry (default: 1 second)
  /// [maxDelay] - Maximum delay between retries (default: 30 seconds)
  /// [factor] - Backoff multiplier (default: 2)
  /// [shouldRetry] - Optional function to determine if error is retryable
  static Future<T> retry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 30),
    double factor = 2.0,
    bool Function(Object)? shouldRetry,
  }) async {
    var attempt = 0;
    var delay = initialDelay;

    while (true) {
      attempt++;
      try {
        return await action();
      } catch (e) {
        // Check if we should retry
        if (shouldRetry != null && !shouldRetry(e)) {
          rethrow;
        }

        // Check if we've exhausted attempts
        if (attempt >= maxAttempts) {
          rethrow;
        }

        // Wait before next attempt
        await Future.delayed(delay);

        // Exponential backoff with max delay
        delay = Duration(
          milliseconds: (delay.inMilliseconds * factor).toInt().clamp(
                initialDelay.inMilliseconds,
                maxDelay.inMilliseconds,
              ),
        );
      }
    }
  }

  /// Check if an error is retryable (network-related)
  static bool isRetryableError(Object error) {
    if (error is NetworkException) {
      // Retry on specific status codes
      if (error.statusCode != null) {
        final code = error.statusCode!;
        // Retry on 408, 429, 500, 502, 503, 504
        return code == 408 || code == 429 || code >= 500 && code < 600;
      }
      return true; // Retry on network errors without status code
    }

    // Retry on timeout errors
    if (error.toString().contains('TimeoutException') ||
        error.toString().contains('timeout')) {
      return true;
    }

    // Don't retry on other errors
    return false;
  }
}
