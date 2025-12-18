import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

/// Centralized error handling utility
/// Provides consistent error messages and logging across the app
class ErrorHandler {
  /// Handle an error and show user-friendly message
  static void handle(
    Object error,
    StackTrace stack,
    BuildContext? context, {
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    // Log error for debugging
    developer.log(
      customMessage ?? 'Error occurred',
      name: 'ErrorHandler',
      error: error,
      stackTrace: stack,
    );

    // Show user-friendly message if context provided
    if (context != null && context.mounted) {
      final message = customMessage ?? _getUserFriendlyMessage(error);

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

  /// Convert technical errors to user-friendly messages
  static String _getUserFriendlyMessage(Object error) {
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
