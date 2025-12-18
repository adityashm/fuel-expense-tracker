/// Application-wide constants
class AppConstants {
  // Prevent instantiation
  AppConstants._();

  // ==================== APP INFO ====================
  static const int maxUsers = 5;
  static const String appName = 'Fuel Expense Tracker';
  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';

  // Indian petrol pump names
  static const List<String> petrolPumpNames = [
    'Indian Oil',
    'Bharat Petroleum',
    'Hindustan Petroleum',
    'Shell',
    'Reliance',
    'Essar',
    'Nayara Energy',
  ];

  // Currency
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';

  // ==================== DATABASE CONSTANTS ====================

  /// Pagination batch size for loading expenses
  static const int paginationBatchSize = 50;

  /// Maximum length for text input fields
  static const int maxTextLength = 500;

  /// Maximum length for notes/description fields
  static const int maxNotesLength = 2000;

  /// Maximum file size for receipt images (5MB)
  static const int maxImageSizeBytes = 5 * 1024 * 1024;

  // ==================== SYNC CONSTANTS ====================

  /// Auto-sync interval
  static const Duration autoSyncInterval = Duration(minutes: 5);

  /// Sync batch size to prevent ANR
  static const int syncBatchSize = 50;

  /// Delay between sync batches in milliseconds
  static const int syncBatchDelayMs = 50;

  // ==================== VALIDATION CONSTANTS ====================

  /// Minimum odometer reading (km)
  static const double minOdometerReading = 0;
  static const double minOdometerKm = minOdometerReading;

  /// Maximum odometer reading (km) - 1 million km
  static const double maxOdometerReading = 1000000;
  static const double maxOdometerKm = maxOdometerReading;

  /// Minimum fuel liters
  static const double minFuelLiters = 0.1;

  /// Maximum fuel liters (reasonable tank size)
  static const double maxFuelLiters = 200;

  /// Minimum fuel amount (currency)
  static const double minFuelAmount = 10;

  /// Maximum fuel amount (currency)
  static const double maxFuelAmount = 10000;

  /// Minimum general expense amount
  static const double minExpenseAmount = 1;

  /// Maximum general expense amount
  static const double maxExpenseAmount = 1000000;

  // ==================== GEOFENCING CONSTANTS ====================

  /// Default geofence radius in meters
  static const double defaultGeofenceRadius = 100.0;

  /// Minimum geofence radius in meters
  static const double minGeofenceRadiusMeters = 10.0;

  /// Maximum geofence radius in meters
  static const double maxGeofenceRadiusMeters = 5000.0;

  /// Location update distance filter in meters
  static const double locationDistanceFilter = 50;

  // ==================== UI CONSTANTS ====================

  /// Scroll trigger threshold for lazy loading (90%)
  static const double scrollTriggerThreshold = 0.9;

  /// Snackbar duration in seconds
  static const int snackbarDurationSeconds = 3;

  // ==================== BUDGET CONSTANTS ====================

  /// Budget warning threshold percentage (80%)
  static const double budgetWarningThreshold = 0.8;

  /// Budget danger threshold percentage (95%)
  static const double budgetDangerThreshold = 0.95;
}

/// Input validation error messages
class ValidationMessages {
  ValidationMessages._();

  static const String requiredField = 'This field is required';
  static const String invalidNumber = 'Please enter a valid number';
  static const String percentageRange = 'Value must be between 0 and 100';
  static String textTooLong(int max) =>
      'Text is too long (max $max characters)';
  static String maxTextLength(int max) =>
      'Text is too long (max $max characters)';
  static String maxNotesLength(int max) =>
      'Notes are too long (max $max characters)';
  static String valueTooSmall(double min) => 'Value must be at least $min';
  static String valueTooLarge(double max) => 'Value cannot exceed $max';
  static String fuelAmountRange(double min, double max) =>
      'Fuel amount must be between $min and $max liters';
  static String expenseAmountRange(double min, double max) =>
      'Amount must be between ₹$min and ₹$max';
  static String odometerRange(double min, double max) =>
      'Odometer must be between $min and $max km';
  static const String invalidDate = 'Please select a valid date';
  static const String futureDateNotAllowed = 'Future dates are not allowed';
  static const String invalidOdometer =
      'Odometer reading must be greater than previous reading';
}

/// API/Error messages
class ErrorMessages {
  ErrorMessages._();

  static const String networkError =
      'Network connection error. Please check your internet.';
  static const String databaseError =
      'Database error occurred. Please try again.';
  static const String permissionDenied =
      'Permission denied. Please grant required permissions.';
  static const String unauthorized =
      'You are not authorized to perform this action.';
  static const String unknownError = 'An unexpected error occurred.';
  static const String syncFailed = 'Sync failed. Changes saved locally.';
}
