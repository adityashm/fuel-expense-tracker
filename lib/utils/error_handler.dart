import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

/// Custom error types for better error handling
class AppError implements Exception {
  const AppError(this.message, [this.code, this.originalError]);

  final String message;
  final String? code;
  final dynamic originalError;

  @override
  String toString() => 'AppError: $message${code != null ? ' ($code)' : ''}';
}

class DatabaseError extends AppError {
  const DatabaseError(super.message, [super.code, super.originalError]);

  /// Check if error is constraint violation
  bool get isConstraintError =>
      originalError is DatabaseException &&
      (originalError as DatabaseException).isUniqueConstraintError();

  /// Check if error is foreign key violation
  bool get isForeignKeyError =>
      originalError is DatabaseException &&
      (originalError as DatabaseException).toString().contains('foreign key');
}

class NetworkError extends AppError {
  const NetworkError(super.message, [super.code, super.originalError]);
}

class SyncError extends AppError {
  const SyncError(super.message, [super.code, super.originalError]);

  /// Check if sync error is retryable
  bool get isRetryable {
    if (originalError is FirebaseException) {
      final code = (originalError as FirebaseException).code;
      return code == 'unavailable' ||
          code == 'deadline-exceeded' ||
          code == 'resource-exhausted';
    }
    return true;
  }
}

class ValidationError extends AppError {
  const ValidationError(super.message, [super.code]);
}

/// Centralized error handling utility
/// Provides consistent error messages and logging across the app
class ErrorHandler {
  ErrorHandler._();
  static final ErrorHandler instance = ErrorHandler._();

  /// Handle an error and show user-friendly message
  static void handle(
    Object error,
    StackTrace stack,
    BuildContext? context, {
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    // Log error for debugging
    instance.logError(error, stack, context: customMessage);

    // Show user-friendly message if context provided
    if (context != null && context.mounted) {
      final message = customMessage ?? instance.getUserMessage(error);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          action: onRetry != null
              ? SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: onRetry,
                )
              : null,
        ),
      );
    }
  }

  /// Convert error to user-friendly message
  String getUserMessage(Object error, {String? context}) {
    if (error is AppError) {
      return error.message;
    }

    if (error is DatabaseException) {
      if (error.isUniqueConstraintError()) {
        return 'This record already exists. Please check for duplicates.';
      }
      if (error.toString().contains('foreign key')) {
        return 'Cannot delete. This item is being used elsewhere.';
      }
      return 'Database error occurred. Please try again.';
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to perform this action.';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again.';
        case 'deadline-exceeded':
          return 'Operation timed out. Please check your connection.';
        case 'not-found':
          return 'The requested data was not found.';
        case 'already-exists':
          return 'This item already exists.';
        default:
          return 'Sync error: ${error.message ?? error.code}';
      }
    }

    if (error is TimeoutException) {
      return 'Operation timed out. Please try again.';
    }

    if (context != null) {
      return '$context failed. Please try again.';
    }

    return 'An unexpected error occurred. Please try again.';
  }

  /// Log error with context
  void logError(
    Object error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    developer.log(
      '❌ ERROR: ${context ?? 'Unknown context'}',
      name: 'ErrorHandler',
      error: error,
      stackTrace: stackTrace,
    );
    if (additionalData != null && additionalData.isNotEmpty) {
      developer.log('Data: $additionalData', name: 'ErrorHandler');
    }
  }

  /// Wrap operation with error handling
  Future<T> wrapAsync<T>(
    Future<T> Function() operation, {
    required String context,
    T Function(Object error)? onError,
    bool shouldRethrow = true,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      logError(error, stackTrace, context: context);

      if (onError != null) {
        return onError(error);
      }

      if (shouldRethrow) {
        rethrow;
      }

      throw AppError(getUserMessage(error, context: context), null, error);
    }
  }

  /// Execute with retry logic
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    required String context,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    bool Function(Object error)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      attempt++;
      try {
        return await operation();
      } catch (error, stackTrace) {
        logError(
          error,
          stackTrace,
          context: context,
          additionalData: {'attempt': attempt, 'maxAttempts': maxAttempts},
        );

        final canRetry = shouldRetry?.call(error) ?? _isRetryableError(error);

        if (attempt >= maxAttempts || !canRetry) {
          rethrow;
        }

        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 2).clamp(
            initialDelay.inMilliseconds,
            const Duration(seconds: 30).inMilliseconds,
          ),
        );
      }
    }
  }

  /// Check if error is retryable
  bool _isRetryableError(Object error) {
    if (error is SyncError) {
      return error.isRetryable;
    }
    if (error is FirebaseException) {
      return error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'resource-exhausted';
    }
    if (error is TimeoutException) {
      return true;
    }
    return false;
  }

  /// Convert technical errors to user-friendly messages (legacy method)
  static String _getUserFriendlyMessage(Object error) {
    return instance.getUserMessage(error);
  }
  
  // Keep existing _getUserFriendlyMessage method for compatibility
  static String getUserFriendlyMessageLegacy(Object error) {
    if (error is DatabaseException) {
      return 'Database error. Please try again.';
    }

    if (error.toString().contains('Firebase')) {
      return 'Sync failed. Check your internet connection.';
    }

    if (error.toString().contains('network') ||
        error.toString().contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    }

    if (error.toString().contains('permission')) {
      return 'Permission denied. Please check app permissions.';
    }

    if (error.toString().contains('storage')) {
      return 'Storage error. Please free up some space.';
    }

    return 'Something went wrong. Please try again.';
  }

  /// Show success message
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show warning message
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show info message
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
