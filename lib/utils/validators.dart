import 'constants.dart';

/// Validation utilities for user input
class InputValidators {
  /// Validate fuel amount (liters)
  static String? validateFuelAmount(double? value) {
    if (value == null || value <= 0) {
      return ValidationMessages.fuelAmountRange(
        AppConstants.minFuelLiters,
        AppConstants.maxFuelLiters,
      );
    }
    if (value < AppConstants.minFuelLiters ||
        value > AppConstants.maxFuelLiters) {
      return ValidationMessages.fuelAmountRange(
        AppConstants.minFuelLiters,
        AppConstants.maxFuelLiters,
      );
    }
    return null;
  }

  /// Validate expense amount (currency)
  static String? validateExpenseAmount(double? value) {
    if (value == null || value <= 0) {
      return ValidationMessages.expenseAmountRange(
        AppConstants.minExpenseAmount,
        AppConstants.maxExpenseAmount,
      );
    }
    if (value < AppConstants.minExpenseAmount ||
        value > AppConstants.maxExpenseAmount) {
      return ValidationMessages.expenseAmountRange(
        AppConstants.minExpenseAmount,
        AppConstants.maxExpenseAmount,
      );
    }
    return null;
  }

  /// Validate odometer reading (km)
  static String? validateOdometer(double? value) {
    if (value == null || value < 0) {
      return ValidationMessages.odometerRange(
        AppConstants.minOdometerKm,
        AppConstants.maxOdometerKm,
      );
    }
    if (value < AppConstants.minOdometerKm ||
        value > AppConstants.maxOdometerKm) {
      return ValidationMessages.odometerRange(
        AppConstants.minOdometerKm,
        AppConstants.maxOdometerKm,
      );
    }
    return null;
  }

  /// Validate text field length
  static String? validateText(String? value,
      {int? maxLength, bool required = false,}) {
    if (required && (value == null || value.trim().isEmpty)) {
      return ValidationMessages.requiredField;
    }
    final effectiveMaxLength = maxLength ?? AppConstants.maxTextLength;
    if (value != null && value.length > effectiveMaxLength) {
      return ValidationMessages.maxTextLength(effectiveMaxLength);
    }
    return null;
  }

  /// Validate notes field
  static String? validateNotes(String? value) {
    if (value != null && value.length > AppConstants.maxNotesLength) {
      return ValidationMessages.maxNotesLength(AppConstants.maxNotesLength);
    }
    return null;
  }

  /// Validate percentage (0-100)
  static String? validatePercentage(double? value) {
    if (value == null || value < 0 || value > 100) {
      return ValidationMessages.percentageRange;
    }
    return null;
  }

  /// Validate required field (generic)
  static String? validateRequired(Object? value, String fieldName) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      return ValidationMessages.requiredField;
    }
    return null;
  }

  /// Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return ValidationMessages.requiredField;
    }
    // Allow common local-part characters including '+', and flexible TLD lengths
    final emailRegex =
        RegExp(r'^[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validate phone number (basic)
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return ValidationMessages.requiredField;
    }
    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  /// Validate latitude
  static String? validateLatitude(double? value) {
    if (value == null || value < -90 || value > 90) {
      return 'Latitude must be between -90 and 90';
    }
    return null;
  }

  /// Validate longitude
  static String? validateLongitude(double? value) {
    if (value == null || value < -180 || value > 180) {
      return 'Longitude must be between -180 and 180';
    }
    return null;
  }

  /// Validate radius (for geofence)
  static String? validateRadius(double? value) {
    if (value == null || value <= 0) {
      return 'Radius must be greater than 0';
    }
    if (value < AppConstants.minGeofenceRadiusMeters ||
        value > AppConstants.maxGeofenceRadiusMeters) {
      return 'Radius must be between ${AppConstants.minGeofenceRadiusMeters}m and ${AppConstants.maxGeofenceRadiusMeters}m';
    }
    return null;
  }

  /// Validate positive number
  static String? validatePositiveNumber(double? value, String fieldName) {
    if (value == null || value <= 0) {
      return '$fieldName must be a positive number';
    }
    return null;
  }

  /// Validate non-negative number
  static String? validateNonNegativeNumber(double? value, String fieldName) {
    if (value == null || value < 0) {
      return '$fieldName must be non-negative';
    }
    return null;
  }
}
